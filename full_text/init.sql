-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create test table
CREATE TABLE test_data (
    id SERIAL PRIMARY KEY,
    content TEXT
);

-- Insert 50 million random strings as test data
INSERT INTO test_data (content)
SELECT md5(random()::text)
FROM generate_series(1, 50000000);

-- Vacuum the table to optimize statistics
VACUUM ANALYZE test_data;
