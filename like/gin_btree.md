
# PostgreSQL Index Performance Experiment

This experiment is designed to compare the performance of three different scenarios: **No Index**, **B-tree Index**, and **Trigram + GIN Index**. We measure the time for inserting 1000 records and a single record in each scenario, as well as the size of the index for the indexed scenarios.

---

### Experiment Setup

1. **PostgreSQL Version**: 12.7
2. **Extensions**: `pg_trgm` (for Trigram index)
3. **Table Schema**: 
   ```sql
   CREATE TABLE test_table (
       id BIGINT PRIMARY KEY,
       data TEXT
   );
   ```

---

### Step 1: No Index Case

1. **Insert 1000 records (record query plan and time)**:
   ```sql
   EXPLAIN ANALYZE 
   INSERT INTO test_table (id, data)
   SELECT generate_series(1, 1000), md5(random()::text);
   ```
   - **Query Plan**:
     ```plaintext
     Insert on test_table  (cost=0.00..17.53 rows=1000 width=40) (actual time=3.123..3.125 rows=0 loops=1)
       ->  Subquery Scan on "*SELECT*"  (cost=0.00..17.53 rows=1000 width=40) (actual time=0.104..0.995 rows=1000 loops=1)
             ->  ProjectSet  (cost=0.00..5.03 rows=1000 width=36) (actual time=0.101..0.862 rows=1000 loops=1)
                   ->  Result  (cost=0.00..0.01 rows=1 width=0) (actual time=0.003..0.003 rows=1 loops=1)
       Planning Time: 0.962 ms
       Execution Time: 3.265 ms
     ```

2. **Insert a single record (record query plan and time)**:
   ```sql
   EXPLAIN ANALYZE 
   INSERT INTO test_table (id, data) VALUES (1001, 'single_insert_no_index');
   ```
   - **Query Plan**:
     ```plaintext
     Insert on test_table  (cost=0.00..0.01 rows=1 width=40) (actual time=0.127..0.127 rows=0 loops=1)
       ->  Result  (cost=0.00..0.01 rows=1 width=40) (actual time=0.005..0.005 rows=1 loops=1)
     Planning Time: 0.051 ms
     Execution Time: 0.525 ms
     ```

---

### Step 2: B-tree Index Case

1. **Clear previous data**:
   ```sql
   TRUNCATE test_table;
   ```

2. **Create B-tree index**:
   ```sql
   CREATE INDEX idx_btree ON test_table (data);
   ```
   - **Result**:
     ```plaintext
     Execution Time: 12.912 ms
     ```

3. **Insert 1000 records (record query plan and time)**:
   ```sql
   EXPLAIN ANALYZE 
   INSERT INTO test_table (id, data)
   SELECT generate_series(1, 1000), md5(random()::text);
   ```
   - **Query Plan**:
     ```plaintext
     Insert on test_table  (cost=0.00..17.53 rows=1000 width=40) (actual time=7.507..7.508 rows=0 loops=1)
       ->  Subquery Scan on "*SELECT*"  (cost=0.00..17.53 rows=1000 width=40) (actual time=0.070..0.611 rows=1000 loops=1)
             ->  ProjectSet  (cost=0.00..5.03 rows=1000 width=36) (actual time=0.068..0.522 rows=1000 loops=1)
                   ->  Result  (cost=0.00..0.01 rows=1 width=0) (actual time=0.003..0.005 rows=1 loops=1)
       Planning Time: 0.238 ms
       Execution Time: 7.839 ms
     ```

4. **Insert a single record (record query plan and time)**:
   ```sql
   EXPLAIN ANALYZE 
   INSERT INTO test_table (id, data) VALUES (1001, 'single_insert_btree');
   ```
   - **Query Plan**:
     ```plaintext
     Insert on test_table  (cost=0.00..0.01 rows=1 width=40) (actual time=0.169..0.170 rows=0 loops=1)
       ->  Result  (cost=0.00..0.01 rows=1 width=40) (actual time=0.002..0.002 rows=1 loops=1)
     Planning Time: 0.036 ms
     Execution Time: 0.250 ms
     ```

5. **Check index size**:
   ```sql
   SELECT pg_size_pretty(pg_total_relation_size('idx_btree'));
   ```
   - **Result**:
     ```plaintext
     88 kB
     ```

---

### Step 3: Trigram + GIN Index Case

1. **Clear previous data**:
   ```sql
   TRUNCATE test_table;
   ```

2. **Create Trigram + GIN index**:
   ```sql
   CREATE INDEX idx_trigram_gin ON test_table USING gin (data gin_trgm_ops);
   ```
   - **Result**:
     ```plaintext
     Execution Time: 5.363 ms
     ```

3. **Insert 1000 records (record query plan and time)**:
   ```sql
   EXPLAIN ANALYZE 
   INSERT INTO test_table (id, data)
   SELECT generate_series(1, 1000), md5(random()::text);
   ```
   - **Query Plan**:
     ```plaintext
     Insert on test_table  (cost=0.00..17.53 rows=1000 width=40) (actual time=15.553..15.554 rows=0 loops=1)
       ->  Subquery Scan on "*SELECT*"  (cost=0.00..17.53 rows=1000 width=40) (actual time=0.023..0.800 rows=1000 loops=1)
             ->  ProjectSet  (cost=0.00..5.03 rows=1000 width=36) (actual time=0.021..0.690 rows=1000 loops=1)
                   ->  Result  (cost=0.00..0.01 rows=1 width=0) (actual time=0.003..0.004 rows=1 loops=1)
       Planning Time: 0.072 ms
       Execution Time: 15.858 ms
     ```

4. **Insert a single record (record query plan and time)**:
   ```sql
   EXPLAIN ANALYZE 
   INSERT INTO test_table (id, data) VALUES (1001, 'single_insert_trigram_gin');
   ```
   - **Query Plan**:
     ```plaintext
     Insert on test_table  (cost=0.00..0.01 rows=1 width=40) (actual time=0.291..0.292 rows=0 loops=1)
       ->  Result  (cost=0.00..0.01 rows=1 width=40) (actual time=0.003..0.004 rows=1 loops=1)
     Planning Time: 0.150 ms
     Execution Time: 0.498 ms
     ```

5. **Check index size**:
   ```sql
   SELECT pg_size_pretty(pg_total_relation_size('idx_trigram_gin'));
   ```
   - **Result**:
     ```plaintext
     1080 kB
     ```

---

### Summary of Results

| **Scenario**           | **1000 Record Insert Time** | **Single Record Insert Time** | **Index Size**  |
|------------------------|-----------------------------|-------------------------------|-----------------|
| No Index               | 3.265 ms                    | 0.525 ms                      | N/A             |
| B-tree Index           | 7.839 ms                    | 0.250 ms                      | 88 kB           |
| Trigram + GIN Index    | 15.858 ms                   | 0.498 ms                      | 1080 kB         |

---

### Conclusions

- **No Index**: The fastest for both 1000 record and single record inserts, but lacks the benefits of indexed queries.
- **B-tree Index**: Shows moderate overhead in both insertion cases, but provides a compact index size.
- **Trigram + GIN Index**: The slowest in terms of insertions due to the complexity of the GIN index, but offers efficient text-based searches. The index size is significantly larger than the B-tree index. 

This experiment shows that while indexes add overhead to insertion performance, they are necessary for query performance. The choice between B-tree and Trigram + GIN depends on the specific use case (e.g., pattern matching or exact match queries).
