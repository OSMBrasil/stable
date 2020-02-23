
CREATE or replace FUNCTION jsonb_strip_nulls_v2(
  p_input jsonb
) RETURNS jsonb AS $f$
  SELECT CASE WHEN x='{}'::JSONb THEN NULL ELSE x END  FROM (SELECT jsonb_strip_nulls($1)) t(x) 
$f$ LANGUAGE SQL IMMUTABLE;


DROP AGGREGATE IF EXISTS array_agg_cat(anyarray) CASCADE;
CREATE AGGREGATE array_agg_cat(anyarray) (
  SFUNC=array_cat,
  STYPE=anyarray,
  INITCOND='{}'
);
