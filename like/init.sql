-- Step 1: Connect to the target database
\c test_db;

-- Step 2: Enable the pg_trgm extension to allow trigram indexing
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm') THEN 
        CREATE EXTENSION pg_trgm; 
        RAISE NOTICE 'pg_trgm extension enabled.'; 
    ELSE 
        RAISE NOTICE 'pg_trgm extension already enabled.'; 
    END IF; 
END $$;

-- Step 3: Create the test table with a TEXT field to simulate real-world data
CREATE TABLE IF NOT EXISTS network_groups (
    id SERIAL PRIMARY KEY,
    network_group_name TEXT
);

-- Step 4: Insert 5 million records to simulate a large dataset
DO $$
BEGIN
    RAISE NOTICE 'Inserting 5 million records...';
END $$;

INSERT INTO network_groups (network_group_name)
SELECT md5(random()::text) || md5(random()::text)
FROM generate_series(1, 5000000);

-- Step 5: Insert performance test without any indexing (baseline)
DO $$
BEGIN
    RAISE NOTICE 'Starting insert performance test without indexing...';
END $$;

EXPLAIN ANALYZE 
INSERT INTO network_groups (network_group_name)
SELECT md5(random()::text) || md5(random()::text)
FROM generate_series(1, 100000);  -- Insert 100k records

-- Step 6: Create GIN index using trigram operator for optimized LIKE queries
DO $$
BEGIN
    RAISE NOTICE 'Creating GIN index with trigram operator...';
END $$;

CREATE INDEX IF NOT EXISTS idx_network_group_name_gin 
ON network_groups USING GIN (network_group_name gin_trgm_ops);

-- Step 7: Insert performance test with the GIN index created
DO $$
BEGIN
    RAISE NOTICE 'Starting insert performance test with GIN indexing...';
END $$;

EXPLAIN ANALYZE 
INSERT INTO network_groups (network_group_name)
SELECT md5(random()::text) || md5(random()::text)
FROM generate_series(1, 100000);  -- Insert 100k records

-- Step 8: Query performance test before creating the index (baseline)
DO $$
BEGIN
    RAISE NOTICE 'Starting query performance test without index...';
END $$;

EXPLAIN ANALYZE 
SELECT * FROM network_groups WHERE network_group_name LIKE '%abc%';

-- Step 9: Query performance test with the GIN index created
DO $$
BEGIN
    RAISE NOTICE 'Starting query performance test with GIN index...';
END $$;

EXPLAIN ANALYZE 
SELECT * FROM network_groups WHERE network_group_name LIKE '%abc%';

-- Step 10: Final summary log for tracking process completion
DO $$
BEGIN
    RAISE NOTICE 'Performance testing completed. Check query plans and timings.';
END $$;
