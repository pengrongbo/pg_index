-- Create pg_trgm extension to enable trigram-based indexing
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create the test table with id and md5 hash columns
CREATE TABLE t_hash AS 
SELECT id, md5(id::text) AS md5_hash 
FROM generate_series(1, 50000000) AS id;

-- Run VACUUM ANALYZE to optimize table statistics
VACUUM ANALYZE;
