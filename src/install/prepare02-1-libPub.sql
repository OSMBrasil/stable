
--
-- Acrescentando funções de uso geral ao schema public.
--


CREATE or replace FUNCTION jsonb_strip_nulls_v2(
  p_input jsonb
) RETURNS jsonb AS $f$
  SELECT CASE WHEN x='{}'::JSONb THEN NULL ELSE x END  FROM (SELECT jsonb_strip_nulls($1)) t(x)
$f$ LANGUAGE SQL IMMUTABLE;

/* pendente mudar para sobrecarga
CREATE or replace FUNCTION jsonb_strip_nulls(
  p_input jsonb,      -- any input
  p_ret_empty boolean -- true for normal, false for ret null on empty
) RETURNS jsonb AS $f$
  SELECT CASE
     WHEN p_ret_empty THEN x
     WHEN x='{}'::JSONb THEN NULL
         ELSE x END
  FROM (SELECT jsonb_strip_nulls(p_input)) t(x)
$f$ LANGUAGE SQL IMMUTABLE;
*/

DROP AGGREGATE IF EXISTS array_agg_cat(anyarray) CASCADE;
CREATE AGGREGATE array_agg_cat(anyarray) (
  SFUNC=array_cat,
  STYPE=anyarray,
  INITCOND='{}'
);
COMMENT ON AGGREGATE array_agg_cat(anyarray)
 IS 'Copy to CSV with optional header';



CREATE or replace FUNCTION copy_csv(
  p_filename text,
  p_query text,
  p_useheader boolean = true,
  p_root text = '/tmp/' ) RETURNS text AS $f$
 BEGIN
  EXECUTE format(
    'COPY (%s) TO %L CSV %s'
    ,CASE WHEN position(' ' in p_query)=0 THEN ('SELECT * FROM '||p_query) ELSE p_query END
    ,p_root||p_filename
    ,CASE WHEN p_useheader THEN 'HEADER' ELSE '' END
  );
  RETURN p_filename;
 END;
$f$ LANGUAGE plpgsql STRICT;
COMMENT ON FUNCTION copy_csv
 IS 'Easy transform query or view-name to COPY-to-CSV, with optional header';
