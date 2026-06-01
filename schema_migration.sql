-- schema_migration.sql
-- Fixes the mixed-up Products table and broken JSON-like customer data.

BEGIN;

-- Split Products into smaller tables by product type
CREATE TABLE IF NOT EXISTS products_base AS TABLE products WITH NO DATA;

CREATE TABLE IF NOT EXISTS physical_products (
    product_id BIGINT PRIMARY KEY,
    weight_kg NUMERIC(8,3),
    dimensions_cm VARCHAR(50),
    description TEXT
);

CREATE TABLE IF NOT EXISTS digital_products (
    product_id BIGINT PRIMARY KEY,
    download_url VARCHAR(512),
    license_type VARCHAR(100),
    metadata_json JSONB
);

CREATE TABLE IF NOT EXISTS financial_products (
    product_id BIGINT PRIMARY KEY,
    interest_rate NUMERIC(5,2),
    tenure_months INT
);

CREATE TABLE IF NOT EXISTS logistics_services (
    product_id BIGINT PRIMARY KEY,
    service_tier VARCHAR(50),
    sla_hours INT
);

-- Move old rows into the new tables
INSERT INTO physical_products (product_id, weight_kg, dimensions_cm, description)
SELECT product_id, weight_kg, dimensions, description FROM products WHERE product_type = 'PHYSICAL';

INSERT INTO digital_products (product_id, download_url, license_type, metadata_json)
SELECT product_id, NULL, NULL, NULL FROM products WHERE product_type = 'DIGITAL';

INSERT INTO financial_products (product_id, interest_rate, tenure_months)
SELECT product_id, NULL, NULL FROM products WHERE product_type = 'FINANCIAL';

INSERT INTO logistics_services (product_id, service_tier, sla_hours)
SELECT product_id, NULL, NULL FROM products WHERE product_type = 'LOGISTICS';

-- Save good customer JSON and send bad rows to an error table
CREATE TABLE IF NOT EXISTS customer_profiles (
    customer_id BIGINT PRIMARY KEY REFERENCES customers(customer_id),
    profile_json JSONB
);

CREATE TABLE IF NOT EXISTS customer_profile_errors (
    customer_id BIGINT PRIMARY KEY,
    raw_profile TEXT,
    error_reason TEXT
);

-- Copy only valid JSON into the new table
INSERT INTO customer_profiles (customer_id, profile_json)
SELECT customer_id, profile_data::jsonb FROM customers WHERE profile_data IS NOT NULL AND (profile_data LIKE '{%' OR profile_data LIKE '[%')
AND (profile_data::jsonb IS NOT NULL);

-- Keep broken JSON rows for cleanup work
INSERT INTO customer_profile_errors (customer_id, raw_profile, error_reason)
SELECT customer_id, profile_data, 'malformed-json' FROM customers
WHERE profile_data IS NOT NULL AND (profile_data::jsonb IS NULL OR profile_data NOT LIKE '{%');

COMMIT;

-- More cleanup jobs can read from these staging tables later.
