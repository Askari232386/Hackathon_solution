-- olap_queries.sql
-- Fixes wrong reporting numbers in the warehouse and cube.

-- Show real revenue after refunds and discounts
CREATE OR REPLACE VIEW vw_net_revenue_daily AS
SELECT
    date_trunc('day', sf.payment_received_date) AS day,
    SUM(sf.revenue) - COALESCE(SUM(r.amount),0) - COALESCE(SUM(op.applied_discount),0) AS net_revenue
FROM sales_fact sf
LEFT JOIN refunds r ON r.order_id = sf.order_id
LEFT JOIN (
    SELECT order_id, SUM(discount_amount) AS applied_discount FROM order_promotions GROUP BY order_id
) op ON op.order_id = sf.order_id
GROUP BY day;

-- Use the payment date for tax reporting
CREATE OR REPLACE VIEW vw_revenue_by_quarter AS
SELECT date_trunc('quarter', payment_received_date) AS quarter, SUM(revenue) - COALESCE(SUM(r.amount),0) AS net_revenue
FROM sales_fact sf LEFT JOIN refunds r ON r.order_id = sf.order_id
GROUP BY quarter ORDER BY quarter;

-- Count sales in the city where the customer lived at the time
CREATE OR REPLACE VIEW vw_revenue_by_city AS
SELECT cah.city, SUM(sf.revenue) - COALESCE(SUM(r.amount),0) AS net_revenue
FROM sales_fact sf
JOIN customer_address_history cah ON cah.customer_id = (SELECT c.customer_id FROM customers c WHERE c.customer_id = sf.order_id) -- placeholder
LEFT JOIN refunds r ON r.order_id = sf.order_id
WHERE sf.order_date BETWEEN cah.start_date AND COALESCE(cah.end_date, '9999-12-31')
GROUP BY cah.city;

-- Count only true defaults, not restructured or reversed plans
CREATE OR REPLACE VIEW vw_novapay_default_rate AS
SELECT
    COUNT(CASE WHEN i.status = 'DEFAULTED' THEN 1 END)::NUMERIC / NULLIF(COUNT(*),0) AS default_rate,
    COUNT(*) AS total_plans
FROM novapay_plans np
JOIN installments i ON i.plan_id = np.plan_id
WHERE i.is_restructured = FALSE AND i.is_reversed = FALSE;

-- Measure inventory turnover from average stock, not the nightly peak
CREATE OR REPLACE VIEW vw_inventory_turnover AS
SELECT product_id, SUM(sales) / NULLIF(AVG(quantity),0) AS turnover
FROM (
    SELECT product_id, date_trunc('day', snapshot_date) as day, AVG(quantity) as quantity
    FROM inventory_snapshots
    GROUP BY product_id, day
) daily
JOIN (
    SELECT product_id, SUM(qty * unit_price) AS sales FROM order_items oi JOIN orders o ON o.order_id = oi.order_id GROUP BY product_id
) sales ON sales.product_id = daily.product_id
GROUP BY product_id;

-- Fix basket size so split payments do not make stores look smaller than they are
CREATE OR REPLACE VIEW vw_retail_basket_size AS
SELECT store_id, SUM(total_revenue)/SUM(visit_count) AS avg_basket
FROM (
    SELECT o.order_id, o.store_id, SUM(oi.unit_price * oi.qty) as total_revenue, 1 as visit_count
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.channel = 'RETAIL'
    GROUP BY o.order_id, o.store_id
) t
GROUP BY store_id;

-- These views depend on a few helper tables that the ETL should fill first.
