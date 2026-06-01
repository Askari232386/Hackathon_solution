-- concurrency.sql
-- Fixes race conditions and deadlocks in checkout and plan updates.

-- Lock stock first, then place the order, so two users cannot sell the same item twice
CREATE OR REPLACE FUNCTION reserve_inventory_and_create_order(p_customer_id BIGINT, p_store_id INT, p_product_id BIGINT, p_qty INT)
RETURNS TABLE(order_id BIGINT) LANGUAGE plpgsql AS $$
DECLARE
    v_quantity BIGINT;
    v_order_id BIGINT;
BEGIN
    LOOP
        -- Lock the stock row before changing it
        SELECT quantity INTO v_quantity FROM inventory WHERE store_id = p_store_id AND product_id = p_product_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Inventory row not found';
        END IF;

        IF v_quantity < p_qty THEN
            RAISE EXCEPTION 'Insufficient stock: have % want %', v_quantity, p_qty;
        END IF;

        -- Do the stock change and order creation together
        UPDATE inventory SET quantity = quantity - p_qty WHERE store_id = p_store_id AND product_id = p_product_id;

        INSERT INTO orders (customer_id, channel, status, total_amount) VALUES (p_customer_id, 'ONLINE', 'PLACED', 0) RETURNING order_id INTO v_order_id;
        INSERT INTO order_items (order_id, product_id, qty, unit_price) VALUES (v_order_id, p_product_id, p_qty, 0);

        RETURN QUERY SELECT v_order_id;
        EXIT;
    END LOOP;
END; $$;

-- Stop lost updates when two requests change the same loan balance at once
ALTER TABLE novapay_plans ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

CREATE OR REPLACE FUNCTION adjust_available_credit(p_plan_id BIGINT, p_delta NUMERIC)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    curr_balance NUMERIC;
    curr_version BIGINT;
BEGIN
    LOOP
        SELECT remaining_balance, version INTO curr_balance, curr_version FROM novapay_plans WHERE plan_id = p_plan_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Plan not found';
        END IF;
        UPDATE novapay_plans SET remaining_balance = remaining_balance + p_delta, version = version + 1 WHERE plan_id = p_plan_id AND version = curr_version;
        EXIT;
    END LOOP;
END; $$;
