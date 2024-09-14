
# PostgreSQL Trigram and GIN Index Performance Test

This document outlines the steps taken to evaluate the performance of inserting and querying data with and without the GIN index using the `pg_trgm` extension in PostgreSQL. 

## Step-by-Step Procedure

### 1. Initial Setup

- Connected to the database: `test_db`
- Created the `network_groups` table:

    ```sql
    CREATE TABLE network_groups (
        id SERIAL PRIMARY KEY,
        network_group_name TEXT
    );
    ```

- Enabled the `pg_trgm` extension:

    ```sql
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    ```

### 2. Inserting 5 Million Records Without Index

- Inserted 5 million rows of data to simulate a large dataset:

    ```sql
    EXPLAIN ANALYZE 
    INSERT INTO network_groups (network_group_name)
    SELECT md5(random()::text) || md5(random()::text)
    FROM generate_series(1, 5000000);
    ```

- **Results**:

    ```
    QUERY PLAN
    Insert on network_groups  (cost=0.00..237500.00 rows=5000000 width=36) (actual time=6760.699..6760.700 rows=0 loops=1)
      ->  Subquery Scan on "*SELECT*"  (cost=0.00..237500.00 rows=5000000 width=36) (actual time=167.906..3298.502 rows=5000000 loops=1)
            ->  Function Scan on generate_series  (cost=0.00..162500.00 rows=5000000 width=32) (actual time=167.854..2471.915 rows=5000000 loops=1)
    Planning Time: 0.069 ms
    Execution Time: 6784.284 ms
    ```

### 3. Query `LIKE '%abc%'` Without Index

- Performed a `LIKE '%abc%'` query:

    ```sql
    EXPLAIN ANALYZE 
    SELECT * FROM network_groups WHERE network_group_name LIKE '%abc%';
    ```

- **Results**:

    ```
    QUERY PLAN
    Gather  (cost=1000.00..93820.90 rows=50505 width=69) (actual time=0.884..309.610 rows=75476 loops=1)
      Workers Planned: 2
      Workers Launched: 2
      ->  Parallel Seq Scan on network_groups  (cost=0.00..87770.40 rows=21044 width=69) (actual time=0.092..298.662 rows=25159 loops=3)
            Filter: (network_group_name ~~ '%abc%'::text)
            Rows Removed by Filter: 1641508
    Planning Time: 0.405 ms
    Execution Time: 311.191 ms
    ```

### 4. Clear Table and Create GIN Index

- Cleared the table:

    ```sql
    TRUNCATE TABLE network_groups;
    ```

- Created a GIN index with the trigram operator:

    ```sql
    CREATE INDEX idx_network_group_name_gin ON network_groups USING GIN (network_group_name gin_trgm_ops);
    ```

### 5. Inserting 5 Million Records With Index

- Inserted another 5 million rows with the index created:

    ```sql
    EXPLAIN ANALYZE 
    INSERT INTO network_groups (network_group_name)
    SELECT md5(random()::text) || md5(random()::text)
    FROM generate_series(1, 5000000);
    ```

- **Results**:

    ```
    QUERY PLAN
    Insert on network_groups  (cost=0.00..237500.00 rows=5000000 width=36) (actual time=90062.097..90062.098 rows=0 loops=1)
      ->  Subquery Scan on "*SELECT*"  (cost=0.00..237500.00 rows=5000000 width=36) (actual time=172.688..3550.419 rows=5000000 loops=1)
            ->  Function Scan on generate_series  (cost=0.00..162500.00 rows=5000000 width=32) (actual time=172.601..2580.969 rows=5000000 loops=1)
    Planning Time: 0.070 ms
    Execution Time: 90098.596 ms
    ```

### 6. Query `LIKE '%abc%'` With Index

- Performed the same `LIKE '%abc%'` query with the GIN index created:

    ```sql
    EXPLAIN ANALYZE 
    SELECT * FROM network_groups WHERE network_group_name LIKE '%abc%';
    ```

- **Results**:

    ```
    QUERY PLAN
    Bitmap Heap Scan on network_groups  (cost=487.41..62553.14 rows=50505 width=69) (actual time=17.806..174.162 rows=74786 loops=1)
      Recheck Cond: (network_group_name ~~ '%abc%'::text)
      Heap Blocks: exact=43541
      ->  Bitmap Index Scan on idx_network_group_name_gin  (cost=0.00..474.78 rows=50505 width=0) (actual time=11.043..11.043 rows=74786 loops=1)
            Index Cond: (network_group_name ~~ '%abc%'::text)
    Planning Time: 0.238 ms
    Execution Time: 176.633 ms
    ```

## Summary

- **Insert Performance**: Inserting 5 million rows without an index took approximately 6.78 seconds, while the same operation with the GIN index took around 90 seconds, showing the overhead of maintaining the index during insertions.
  
- **Query Performance**: The `LIKE '%abc%'` query without the index took around 311 ms, whereas the same query with the GIN index completed in about 176 ms, demonstrating a significant performance improvement.
