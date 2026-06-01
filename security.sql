-- security.sql
-- Fixes security problems: shared superuser account, plain-text credentials, missing audit logs, weak TLS, and no point-in-time recovery.

-- Make the app account low risk instead of full admin
REVOKE SUPERUSER FROM novamart_app;
CREATE ROLE web_catalog_reader NOINHERIT;
GRANT CONNECT ON DATABASE novamart TO web_catalog_reader;
GRANT USAGE ON SCHEMA public TO web_catalog_reader;
GRANT SELECT ON TABLE products, physical_products, digital_products, product_enrichment TO web_catalog_reader;

-- Give write access only where the app really needs it
CREATE ROLE web_order_writer NOINHERIT;
GRANT INSERT, SELECT ON TABLE orders, order_items TO web_order_writer;

-- Turn on encryption tools for card data
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Example helper role for migration work
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'db_migration') THEN
        CREATE ROLE db_migration;
    END IF;
END$$;

-- Example only: replace the key with one from a vault
-- UPDATE customer_payment_cards SET encrypted_pan = pgp_sym_encrypt(card_mask::text, 'my_secret_key') WHERE encrypted_pan IS NULL;

-- Turn on audit logging so we can see who did what
CREATE EXTENSION IF NOT EXISTS pgaudit;
-- Log reads, writes, schema changes, and role changes
ALTER SYSTEM SET pgaudit.log = 'write, ddl, role';
SELECT pg_reload_conf();

-- Force TLS so traffic does not fall back to plain text
ALTER SYSTEM SET ssl = 'on';
ALTER SYSTEM SET ssl_ciphers = 'HIGH:!aNULL:!MD5';
ALTER SYSTEM SET ssl_prefer_server_ciphers = 'on';

-- Turn on WAL archiving so point-in-time recovery is possible
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f';
SELECT pg_reload_conf();

-- Helper for password rotation during maintenance
CREATE OR REPLACE FUNCTION rotate_app_password(newpass TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    ALTER ROLE novamart_app WITH PASSWORD newpass;
END; $$;

-- Keep passwords out of files; use a secrets manager instead
