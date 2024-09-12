CREATE TABLE t_autocomplete (
    id SERIAL PRIMARY KEY,
    name TEXT
);


INSERT INTO t_autocomplete (name)
SELECT md5(i::text)
FROM generate_series(1, 50000000) AS i;


VACUUM ANALYZE t_autocomplete;
