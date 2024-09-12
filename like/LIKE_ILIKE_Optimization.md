
# 使用 LIKE 和 ILIKE 的优化策略

LIKE 和 ILIKE 是 SQL 中常用的模糊匹配功能，经常在应用程序中使用。为了提升这些操作的性能，PostgreSQL 提供了多种手段。本文讨论了如何通过索引来加速 LIKE 和 ILIKE 操作，并对不同索引类型的效率进行对比，帮助我们选择合适的优化方案。

## 示例数据的生成

为了测试性能，我们创建了一张包含 5000 万条数据的表，每条记录是一个 ID 和对应的 MD5 哈希值：

```sql
CREATE TABLE t_hash AS SELECT id, md5(id::text) FROM generate_series(1, 50000000) AS id;
VACUUM ANALYZE;
```

## 执行 LIKE 查询

首先，我们使用一个简单的 LIKE 查询：

```sql
SELECT * FROM t_hash WHERE md5 LIKE '%e2345679a%';
```

在一台 iMac 上执行该查询需要 4.7 秒，这在大多数应用场景中是不够理想的。为了找出问题所在，我们查看了查询计划，发现 PostgreSQL 进行了并行序列扫描，这意味着整个表都被扫描了。

## 引入 pg_trgm 扩展

为了提升性能，我们可以使用 `pg_trgm` 扩展，它实现了三元组（trigram）索引，支持模糊搜索。首先启用扩展：

```sql
CREATE EXTENSION pg_trgm;
```

## 测试 Gist 索引

`pg_trgm` 支持两种索引类型：Gist 和 GIN。我们首先尝试创建 Gist 索引：

```sql
CREATE INDEX idx_gist ON t_hash USING gist (md5 gist_trgm_ops);
```

虽然索引创建耗时接近 40 分钟，但查询性能反而更差，需要 1 分 45 秒。这表明 Gist 索引在这种场景下并不合适。

## 测试 GIN 索引

接下来，我们使用 GIN 索引：

```sql
CREATE INDEX idx_gin ON t_hash USING gin (md5 gin_trgm_ops);
```

GIN 索引的创建时间为 11 分钟，但查询时间大幅减少至 75 毫秒，远远优于未使用索引时的 4.7 秒，性能得到了显著提升。

## Btree 索引

虽然 GIN 索引对模糊匹配有很好的效果，但它并不能加速 `=` 操作，因此还需要创建一个 Btree 索引来处理普通的精确匹配查询：

```sql
CREATE INDEX idx_btree ON t_hash (md5);
```

Btree 索引能够将精确匹配的查询时间减少到 0.379 毫秒。

## 结论

PostgreSQL 提供了多种索引机制来提升 LIKE 和 ILIKE 查询的性能。对于模糊匹配，使用 GIN 索引效果最佳，但它需要与 Btree 索引配合使用，以优化不同类型的查询。通过合理选择索引类型，PostgreSQL 的性能可以得到显著提升。
