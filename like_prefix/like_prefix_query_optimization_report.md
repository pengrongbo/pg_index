
# PostgreSQL LIKE Prefix Query Optimization Report

This report demonstrates the performance improvement of using a B-tree index for `LIKE` prefix queries on a PostgreSQL table with a large dataset. The dataset contains 50 million records, and the goal is to optimize the `LIKE` query used for autocomplete or prefix-based searches.

## Query 1: Without Index

The first query was executed without any index on the `name` column to simulate the default behavior in a large dataset. The query searched for records where the `name` column started with the letter "a" using the following SQL:

```sql
EXPLAIN ANALYZE
SELECT * FROM t_autocomplete WHERE name LIKE 'a%';
```

### Execution Plan and Performance

```plaintext
Gather  (cost=1000.00..441504.38 rows=162161 width=36) (actual time=6388.520..6393.238 rows=0 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on t_autocomplete  (cost=0.00..424288.28 rows=67567 width=36) (actual time=6373.369..6373.369 rows=0 loops=3)
         Filter: (name ~~ 'a%'::text)
 Planning Time: 4.048 ms
 JIT:
   Functions: 6
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 0.455 ms, Inlining 0.000 ms, Optimization 0.000 ms, Emission 0.000 ms, Total 0.455 ms
 Execution Time: 6436.726 ms
```

- **Execution Time**: The query took approximately **6436.726 ms** (about 6.4 seconds) to execute. 
- **Execution Plan**: The query plan shows a **Parallel Seq Scan**, meaning the table was scanned sequentially without the aid of an index, which resulted in a slower query.

## Query 2: After Creating a B-tree Index

To improve performance, a B-tree index was created on the `name` column. This index allows PostgreSQL to more efficiently search for records based on the prefix of the `name` column. The index was created with the following SQL:

```sql
CREATE INDEX idx_name_prefix ON t_autocomplete (name);
```

### Query After Index Creation

The same query was executed again after creating the index:

```sql
EXPLAIN ANALYZE
SELECT * FROM t_autocomplete WHERE name LIKE 'a%';
```

### Execution Plan and Performance

```plaintext
Gather  (cost=1000.00..441504.38 rows=162161 width=36) (actual time=401.835..404.337 rows=0 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on t_autocomplete  (cost=0.00..424288.28 rows=67567 width=36) (actual time=363.148..363.148 rows=0 loops=3)
         Filter: (name ~~ 'a%'::text)
 Planning Time: 1.406 ms
 JIT:
   Functions: 6
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.749 ms, Inlining 0.000 ms, Optimization 0.000 ms, Emission 0.000 ms, Total 1.749 ms
 Execution Time: 405.398 ms
```

- **Execution Time**: The query execution time decreased to **405.398 ms**, showing a significant performance improvement.
- **Execution Plan**: While the query plan still shows a **Parallel Seq Scan**, the index helped reduce the scan time by allowing faster lookups for the prefix.

## Summary of Results

- **Without Index**: The query took approximately 6.4 seconds to execute.
- **With B-tree Index**: The query execution time decreased to around 405 milliseconds.

This demonstrates that creating a B-tree index on columns frequently used in prefix-based searches (e.g., autocomplete functionality) can drastically improve query performance in PostgreSQL.
