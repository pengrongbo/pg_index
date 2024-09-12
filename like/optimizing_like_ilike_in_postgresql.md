
# Optimizing LIKE and ILIKE Queries in PostgreSQL

`LIKE` and `ILIKE` are common SQL operators used for pattern matching. Since they are frequently used in applications, it's important to consider performance optimizations. This article discusses how PostgreSQL can improve performance for these operations by using appropriate indexing techniques, and how to achieve better performance.

## Generating Sample Data

To demonstrate the performance improvements, we will work with a table containing 50 million rows of sample data. Instead of searching for ready-made datasets, we generate some sample data using a simple MD5 hash for demonstration purposes:

```sql
CREATE TABLE t_hash AS SELECT id, md5(id::text) FROM generate_series(1, 50000000) AS id;
VACUUM ANALYZE;
```

The table now contains 50 million rows of `id` values and their MD5 hashes.

## Running a Simple LIKE Query

Now let's run a simple `LIKE` query that searches for a substring within the hash. Note that the query uses a wildcard (`%`) both at the start and the end of the string:

```sql
SELECT * FROM t_hash WHERE md5 LIKE '%e2345679a%';
```

On a typical iMac, this query takes around **4.7 seconds**. For most applications, this is too long, and the query will likely overload the server. To understand what’s happening, we can inspect the query execution plan:

```sql
EXPLAIN SELECT * FROM t_hash WHERE md5 LIKE '%e2345679a%';
```

The query plan shows a **parallel sequence scan**, which is efficient for large tables but still involves scanning the entire table (over 3.2GB) to find a single row.

## Using pg_trgm Extension

Fortunately, PostgreSQL offers the `pg_trgm` extension, which is optimized for pattern matching queries using trigrams. This extension supports both `Gist` and `GIN` indexes, which we will evaluate. First, enable the extension:

```sql
CREATE EXTENSION pg_trgm;
```

### Gist Index

To start, let’s create a Gist index:

```sql
CREATE INDEX idx_gist ON t_hash USING gist (md5 gist_trgm_ops);
```

The Gist index takes around **40 minutes** to build, and its size is 8.7GB—much larger than the table itself. Unfortunately, when we run the query again, the performance is worse, taking **1 minute and 45 seconds**. Gist indexes are not always ideal for this type of search, as evidenced by the query execution time.

### GIN Index

Next, we try creating a GIN index, which is often used for full-text search in PostgreSQL:

```sql
CREATE INDEX idx_gin ON t_hash USING gin (md5 gin_trgm_ops);
```

The GIN index is built in **11 minutes**, and when we run the `LIKE` query again, the execution time drops to **75 milliseconds**—a major improvement over the previous 4.7 seconds.

### Btree Index for Exact Matches

While GIN indexes are excellent for pattern matching, they do not improve the performance of exact matches (i.e., `=`). For this, we need to create a **Btree** index:

```sql
CREATE INDEX idx_btree ON t_hash (md5);
```

With the Btree index in place, exact match queries run in **0.379 milliseconds**.

## Conclusion

PostgreSQL offers a variety of powerful indexing strategies. While GIN indexes excel in pattern matching queries, Btree indexes are necessary for optimizing exact match queries. Choosing the right index type can significantly improve the performance of `LIKE` and `ILIKE` queries, ensuring your PostgreSQL database is fast and efficient.
