
# PostgreSQL Performance Testing Experiment (With GIN and Gist Indexing)

This document provides a detailed report of the PostgreSQL performance testing experiment using GIN and Gist indexing strategies. The experiment was conducted to compare performance under no index, GIN index, and Gist index conditions, focusing on bulk insertion, single record insertion, and `LIKE` query optimizations.

## Experiment Setup

- **PostgreSQL version**: 12.7
- **Extensions**: `pg_trgm` (for GIN and Gist indexing)

## Experiment Objectives

1. Test the performance of bulk data insertion under no index, GIN index, and Gist index conditions.
2. Compare the performance of single record insertion under different indexing conditions.
3. Analyze query performance using query plans and execution times across different indexing strategies, particularly for `LIKE` queries.

## Experiment Steps

### Step 1: Docker Initialization with PostgreSQL 12.7

1. **Create Dockerfile and docker-compose.yml** to set up a PostgreSQL 12.7 environment and enable the `pg_trgm` extension.

**Dockerfile**:
```dockerfile
FROM postgres:12.7

# Install PostgreSQL contrib extensions for version 12.7
RUN apt-get update && apt-get install -y postgresql-contrib

# Set default environment variables for PostgreSQL
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=test_db

# Initialize the pg_trgm extension
COPY ./init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432
```

**docker-compose.yml**:
```yaml
version: '3.1'

services:
  postgres:
    build: .
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: test_db
    volumes:
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: always
```

2. **Create an initialization SQL file (init.sql)** that only enables the `pg_trgm` extension:

```sql
-- Initialize pg_trgm extension
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

3. **Start the Docker container**, ensuring the PostgreSQL 12.7 environment is properly configured:
   ```bash
   docker-compose up --build
   ```

### Step 2: Performance Testing Without Index

1. **Create the experimental table**:
   ```sql
   CREATE TABLE t_hash (
     id BIGINT PRIMARY KEY,
     md5 TEXT
   );
   ```

2. **Insert 50 million records and record the time**:
   ```sql
   \timing on
   INSERT INTO t_hash (id, md5)
   SELECT id, md5(id::text)
   FROM generate_series(1, 50000000) AS id;
   -- Result: 43.965 seconds
   ```

3. **Insert a single record and record the time**:
   ```sql
   EXPLAIN ANALYZE INSERT INTO t_hash (id, md5) VALUES (50000001, md5('50000001'));
   -- Query Plan:
   Insert on t_hash  (cost=0.00..0.01 rows=1 width=40) (actual time=0.103..0.103 rows=0 loops=1)
     ->  Result  (cost=0.00..0.01 rows=1 width=40) (actual time=0.008..0.008 rows=1 loops=1)
   Planning Time: 0.185 ms
   Execution Time: 0.145 ms
   -- Time: 4.860 ms
   ```

4. **Test the LIKE query performance and retrieve the query plan**:
   ```sql
   EXPLAIN ANALYZE SELECT * FROM t_hash WHERE md5 LIKE '%e2345679a%';
   -- Query Plan:
   Gather  (cost=1000.00..760906.95 rows=5607 width=40) (actual time=3124.267..3842.714 rows=1 loops=1)
     Workers Planned: 2
     Workers Launched: 2
     ->  Parallel Seq Scan on t_hash  (cost=0.00..759346.25 rows=2336 width=40) (actual time=3568.605..3807.000 rows=0 loops=3)
           Filter: (md5 ~~ '%e2345679a%'::text)
           Rows Removed by Filter: 16666667
   Planning Time: 1.901 ms
   Execution Time: 3844.389 ms
   -- Time: 3.852 seconds
   ```

### Step 3: Performance Testing with GIN Index

1. **Create the GIN index** (after ensuring the `pg_trgm` extension is installed):
   ```sql
   CREATE EXTENSION IF NOT EXISTS pg_trgm;
   CREATE INDEX idx_gin ON t_hash USING gin (md5 gin_trgm_ops);
   -- Result: 6.189 seconds
   ```

2. **Insert 50 million records and record the time**:
   ```sql
   \timing on
   INSERT INTO t_hash (id, md5)
   SELECT id, md5(id::text)
   FROM generate_series(1, 50000000) AS id;
   -- Result: 8 minutes 35.559 seconds
   ```

3. **Insert a single record and record the time**:
   ```sql
   EXPLAIN ANALYZE INSERT INTO t_hash (id, md5) VALUES (50000001, md5('50000001'));
   -- Query Plan:
   Insert on t_hash  (cost=0.00..0.01 rows=1 width=40) (actual time=0.588..0.588 rows=0 loops=1)
     ->  Result  (cost=0.00..0.01 rows=1 width=40) (actual time=0.010..0.010 rows=1 loops=1)
   Planning Time: 0.196 ms
   Execution Time: 0.730 ms
   -- Time: 3.266 ms
   ```

4. **Test the LIKE query performance and retrieve the query plan**:
   ```sql
   EXPLAIN ANALYZE SELECT * FROM t_hash WHERE md5 LIKE '%e2345679a%';
   -- Query Plan:
   Bitmap Heap Scan on t_hash  (cost=1104.00..1108.01 rows=1 width=41) (actual time=200.510..200.511 rows=1 loops=1)
     Recheck Cond: (md5 ~~ '%e2345679a%'::text)
     Heap Blocks: exact=1
     ->  Bitmap Index Scan on idx_gin  (cost=0.00..1104.00 rows=1 width=0) (actual time=200.489..200.489 rows=1 loops=1)
           Index Cond: (md5 ~~ '%e2345679a%'::text)
   Planning Time: 5.125 ms
   Execution Time: 200.584 ms
   -- Time: 208.100 ms
   ```

5. **Delete 50 million records:**
   ```sql
   DELETE FROM t_hash;
   -- Result: 21.068 seconds
   ```

### Step 4: Performance Testing with Gist Index

1. **Create the Gist index**:
   ```sql
   CREATE INDEX idx_gist ON t_hash USING gist (md5 gist_trgm_ops);
   -- Result: 6.480 seconds
   ```

2. **Insert 50 million records and record the time**:
   ```sql
   \timing on
   INSERT INTO t_hash (id, md5)
   SELECT id, md5(id::text)
   FROM generate_series(1, 50000000) AS id;
   -- Result: 25 minutes 16.865 seconds
   ```

3. **Insert a single record and record the time**:
   ```sql
   EXPLAIN ANALYZE INSERT INTO t_hash (id, md5) VALUES (50000001, md5('50000001'));
   -- Query Plan:
   Insert on t_hash  (cost=0.00..0.01 rows=1 width=40) (actual time=0.908..0.909 rows=0 loops=1)
     ->  Result  (cost=0.00..0.01 rows=1 width=40) (actual time=0.009..0.010 rows=1 loops=1)
   Planning Time: 0.351 ms
   Execution Time: 1.080 ms
   -- Time: 6.575 ms
   ```

4. **Test the LIKE query performance and retrieve the query plan**:
   ```sql
   EXPLAIN ANALYZE SELECT * FROM t_hash WHERE md5 LIKE '%e2345679a%';
   -- Query Plan:
   Index Scan using idx_gist on t_hash  (cost=0.50..8.52 rows=1 width=41) (actual time=20849.493..35412.796 rows=1 loops=1)
     Index Cond: (md5 ~~ '%e2345679a%'::text)
   Planning Time: 2.663 ms
   Execution Time: 35412.875 ms
   -- Time: 35.417 seconds
   ```

## Summary and Conclusion

### GIN Index
- **Strengths**: GIN is particularly suited for full-text searches and LIKE/ILIKE queries, making it highly efficient for pattern matching. The GIN index provided exceptional performance for the LIKE query, reducing execution time from nearly 4 seconds (without an index) to **208 ms**.
- **Weaknesses**: The GIN index imposes some performance penalties during bulk insertions. Inserting 50 million records took around **8 minutes 35 seconds**, which is significantly longer than the time required without an index.
- **Best for**: Full-text operations, LIKE/ILIKE queries.

### Gist Index
- **Strengths**: Gist indexing is ideal for geometric data and some advanced indexing cases.
- **Weaknesses**: The Gist index performed poorly in both insertion and query operations compared to the GIN index. The LIKE query took **35 seconds**, far worse than the GIN index. Inserting 50 million records also took much longer (**25 minutes 16 seconds**), making it inefficient for large datasets.
- **Best for**: Geometric data (GIS) or specific spatial queries but **not** recommended for general pattern matching (LIKE/ILIKE queries).

### Conclusion
The experiment demonstrates that **GIN indexing** is the clear winner for optimizing `LIKE` queries in PostgreSQL 12.7. While Gist can be useful for specialized data types, it is not suitable for text pattern matching due to its slow query and insertion performance. GIN is a much better option for applications involving large datasets and frequent text-based queries (e.g., full-text search or pattern matching).
