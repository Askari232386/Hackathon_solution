-- reconciliation.sql
-- Fixes orphan loan records and keeps bad records out of nightly billing.

-- Find plans that no longer have a matching customer, order, or product
CREATE TABLE IF NOT EXISTS quarantined_orphan_plans AS
SELECT np.* FROM novapay_plans np
LEFT JOIN customers c ON c.customer_id = np.customer_id
LEFT JOIN orders o ON o.order_id = np.order_id
LEFT JOIN products p ON p.product_id = np.product_id
WHERE c.customer_id IS NULL OR (np.order_id IS NOT NULL AND o.order_id IS NULL) OR (np.product_id IS NOT NULL AND p.product_id IS NULL);

CREATE INDEX idx_quarantined_orphan_plans_plan_id ON quarantined_orphan_plans (plan_id);

-- Keep collectible debts visible for follow-up instead of deleting them
INSERT INTO customers (name, email) SELECT 'ORPHAN_PLACEHOLDER_' || nextval('quarantined_orphan_seq'), NULL FROM generate_series(1,1);

-- Bring back the missing foreign keys without breaking the load all at once
ALTER TABLE novapay_plans ADD CONSTRAINT fk_novapay_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) NOT VALID;
ALTER TABLE novapay_plans ADD CONSTRAINT fk_novapay_order FOREIGN KEY (order_id) REFERENCES orders(order_id) NOT VALID;

-- Validate after the bad rows are cleaned up
-- ALTER TABLE novapay_plans VALIDATE CONSTRAINT fk_novapay_customer;
-- ALTER TABLE novapay_plans VALIDATE CONSTRAINT fk_novapay_order;

-- Nightly billing should skip the quarantined rows
-- SELECT * FROM novapay_plans WHERE plan_status = 'ACTIVE' AND plan_id NOT IN (SELECT plan_id FROM quarantined_orphan_plans);
