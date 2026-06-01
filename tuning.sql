-- tuning.sql
-- Fixes performance problems: default PostgreSQL settings, slow queries, and poor vacuum behavior.

-- Give PostgreSQL settings that match the real server hardware
ALTER SYSTEM SET shared_buffers = '32GB';
ALTER SYSTEM SET effective_cache_size = '96GB';
ALTER SYSTEM SET work_mem = '64MB';
ALTER SYSTEM SET maintenance_work_mem = '4GB';
ALTER SYSTEM SET max_parallel_workers_per_gather = '8';
ALTER SYSTEM SET max_worker_processes = '32';

-- Keep the database connection count under control
ALTER SYSTEM SET max_connections = '200';

-- Make vacuum and stats refresh run often enough
ALTER SYSTEM SET autovacuum = 'on';
ALTER SYSTEM SET autovacuum_max_workers = '6';
ALTER SYSTEM SET autovacuum_vacuum_scale_factor = '0.05';
ALTER SYSTEM SET autovacuum_analyze_scale_factor = '0.02';
ALTER SYSTEM SET autovacuum_vacuum_cost_delay = '20ms';

-- Make checkpoints less stressful on the disk
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET checkpoint_timeout = '10min';
ALTER SYSTEM SET checkpoint_completion_target = '0.9';

-- Help the planner make better choices
ALTER SYSTEM SET default_statistics_target = '500';

-- Reload the new settings
SELECT pg_reload_conf();

-- Quick check for the main tuning values
-- SELECT name, setting FROM pg_settings WHERE name IN ('shared_buffers','work_mem','effective_cache_size');
