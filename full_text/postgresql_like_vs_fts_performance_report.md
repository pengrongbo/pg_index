
# PostgreSQL `LIKE` vs Full-Text Search Performance Experiment

## Objective

This experiment compares the performance of `LIKE` queries and Full-Text Search (FTS) in PostgreSQL, focusing on:

1. **Query performance** before and after applying `GIN` indexes.
2. **Write performance** (insertion) with and without indexes.

## Setup

1. **Test Environment**:
   - PostgreSQL 14+ with `pg_trgm` and `pg_stat_statements` extensions enabled.
   - Sample table `test_data` with 50 million rows of random strings (MD5 hashes).
   
2. **Indexes Used**:
   - **GIN index** for Full-Text Search: `to_tsvector('english', content)`
   - **GIN index** for `LIKE` query: `content gin_trgm_ops`

## Experiment Steps

### 1. Query Performance

#### 1.1 `LIKE` Query without Index

- **Query**:
  ```sql
  SELECT * FROM test_data WHERE content LIKE '%abc%';
  ```

- **Execution Time**: **200.800 ms**  
- **Execution Plan**:
  - A **parallel sequential scan** was used, with no index support.
  - **Execution Time**: **1.317 seconds**

```sql
EXPLAIN ANALYZE SELECT * FROM test_data WHERE content LIKE '%abc%';
```

- **Parallel Seq Scan Details**:
  - Workers launched: 2
  - Rows scanned: 364,990 rows
  - Rows filtered: **16,545,003** rows removed by the filter.
  - **Execution Time**: **1.317 seconds**

#### 1.2 Full-Text Search with GIN Index

- **Index Creation**:
  ```sql
  CREATE INDEX idx_fts ON test_data USING gin (to_tsvector('english', content));
  ```

  - **Creation Time**: **309,667 ms** (5 minutes 9 seconds)

- **Query**:
  ```sql
  SELECT * FROM test_data WHERE to_tsvector('english', content) @@ plainto_tsquery('abc');
  ```

  - **Execution Time**: **63.297 ms**
  - **Execution Plan**:
    - A **Parallel Bitmap Heap Scan** was used with the GIN index.
    - **Execution Time**: **45.097 ms**

```sql
EXPLAIN ANALYZE SELECT * FROM test_data WHERE to_tsvector('english', content) @@ plainto_tsquery('abc');
```

- **Bitmap Index Scan Details**:
  - Workers launched: 2
  - **Execution Time**: **45.097 ms**
  - Index Scan executed but no rows were found.

#### 1.3 `LIKE` Query with GIN Index

- **Index Creation**:
  ```sql
  CREATE INDEX idx_gin_like ON test_data USING gin (content gin_trgm_ops);
  ```

  - **Creation Time**: **240,287 ms** (4 minutes)

- **Query**:
  ```sql
  SELECT * FROM test_data WHERE content LIKE '%abc%';
  ```

  - **Execution Time**: **1,317 ms**  
  - **Execution Plan**:
    - A **Parallel Seq Scan** was used, but faster due to the GIN index.
    - **Execution Time**: **1.317 seconds**

```sql
EXPLAIN ANALYZE SELECT * FROM test_data WHERE content LIKE '%abc%';
```

### 2. Write Performance

#### 2.1 Insertion Without Indexes

- **Operation**:
  ```sql
  INSERT INTO test_data (content)
  SELECT md5(random()::text) FROM generate_series(1, 100000);
  ```

  - **Insertion Time**: **170.409 ms** (very fast without indexes).

#### 2.2 Insertion With GIN Indexes

After recreating the indexes, we repeat the insertion of 100,000 new rows:

```sql
CREATE INDEX idx_gin_like ON test_data USING gin (content gin_trgm_ops);
CREATE INDEX idx_fts ON test_data USING gin (to_tsvector('english', content));

INSERT INTO test_data (content)
SELECT md5(random()::text)
FROM generate_series(1, 100000);
```

- **Insertion Time**: **2,645.472 ms** (slower due to index maintenance).
  
- **Index Creation Times**:
  - GIN index for `LIKE`: **237,780 ms** (3 minutes 57 seconds)
  - GIN index for FTS: **322,302 ms** (5 minutes 22 seconds)

## Results Summary

| Operation                           | Time (ms)       |
|--------------------------------------|-----------------|
| `LIKE` query without index           | 200.800 ms      |
| `LIKE` query with GIN index          | 1,317 ms        |
| Full-Text Search with GIN index      | 63.297 ms       |
| GIN index creation for `LIKE`        | 240,287 ms      |
| GIN index creation for FTS           | 309,667 ms      |
| Insertion (without indexes)          | 170 ms          |
| Insertion (with indexes)             | 2,645 ms        |

## Conclusions

1. **Query Performance**:
   - Full-Text Search with a GIN index significantly outperforms the `LIKE` query with a GIN index, achieving a query time of just **63.297 ms**, compared to **1,317 ms** for the `LIKE` query.
   - Even after applying a GIN index, `LIKE` queries still have a higher execution time due to the complexity of scanning and filtering large datasets.

2. **Write Performance**:
   - Inserting data without indexes was extremely fast (**170 ms**), but inserting with both GIN indexes slowed down significantly to **2,645 ms** due to the overhead of maintaining the indexes.
   
3. **Recommendation**:
   - For applications that require frequent pattern searches, Full-Text Search is more efficient, particularly when paired with a GIN index.
   - However, for write-heavy workloads, the overhead of maintaining GIN indexes needs to be carefully considered, as it can significantly impact insert performance.
