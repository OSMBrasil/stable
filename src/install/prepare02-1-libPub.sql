
--
-- Acrescentando funções de uso geral ao schema public.
--

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
COMMENT ON AGGREGATE FUNCTION jsonb_strip_nulls(jsonb,boolean)
 IS 'Extends jsonb_strip_nulls to return NULL instead empty';


DROP AGGREGATE IF EXISTS array_agg_cat(anyarray) CASCADE;
CREATE AGGREGATE array_agg_cat(anyarray) (
  SFUNC=array_cat,
  STYPE=anyarray,
  INITCOND='{}'
);
COMMENT ON AGGREGATE array_agg_cat(anyarray)
 IS 'Copy to CSV with optional header';

--
-- Managing COMMENTS:
--

CREATE FUNCTION rel_description(
   p_relname text, p_schemaname text DEFAULT NULL
) RETURNS text AS $f$
  SELECT obj_description((CASE
     WHEN strpos($1, '.')>0 THEN $1
     WHEN $2 IS NULL THEN 'public.'||$1
     ELSE $2||'.'||$1
          END)::regclass, 'pg_class');
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION rel_description(text,text)
 IS E'Alternative shortcut to obj_description(). \nSee https://stackoverflow.com/a/12736192/287948';

CREATE FUNCTION col_description(
 p_relname text,  -- table name or schema.table
 p_colname text,   -- table's column name
 p_database text DEFAULT NULL -- NULL for current
) RETURNS text AS $f$
 WITH r AS (
   SELECT CASE WHEN array_length(x,1)=1 THEN array['public',x[1]] ELSE x END
   FROM regexp_split_to_array(p_relname,'\.') t(x)
  )
 SELECT col_description(p_relname::regClass, ordinal_position)
 FROM r, information_schema.columns i
 WHERE i.table_catalog = CASE
     WHEN $3 IS NULL THEN current_database() ELSE $3
   END and i.table_schema  = r.x[1]
   and i.table_name    = r.x[2]
   and i.column_name = p_colname
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION col_description(text,text,text)
 IS E'Complement for col_description(text,oid). \nSee https://stackoverflow.com/a/12736192/287948';

--
-- FILE SYSTEM:
--

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

CREATE or replace FUNCTION file_get_contents(p_file text) RETURNS text AS $$
   with open(args[0],"r") as content_file:
       content = content_file.read()
   return content
$$ LANGUAGE PLpythonU;
COMMENT ON FUNCTION file_get_contents
 IS 'Gambiarra para ler arquivo, até testar a melhor opção com funções nativas pg';

CREATE or replace FUNCTION file_put_contents(
p_file text,
p_content text,
p_msg text DEFAULT ' (file "%s" saved!) '
) RETURNS text AS $$
  o=open(args[0],"w")
  o.write(args[1])
  o.close()
  if args[2] and args[2].find('%s')>0 :
    return (args[2] % args[0])
  else:
    return args[2]
$$ LANGUAGE PLpythonU;
COMMENT ON FUNCTION file_get_contents
 IS 'Gambiarra para escrever arquivo, até testar a melhor opção com funções nativas pg';

--
-- POSTGIS:
--

CREATE OR REPLACE FUNCTION st_read_geojson(
p_path text,
p_ext text DEFAULT '.geojson',
p_basepath text DEFAULT '/opt/gits/city-codes/data/dump_osm/'::text,
p_srid int DEFAULT 4326
) RETURNS geometry AS $f$
  SELECT CASE WHEN length(s)<30 THEN NULL ELSE ST_GeomFromGeoJSON_sanitized(s::jsonb) END
  FROM  ( SELECT file_get_contents(p_basepath||p_path||p_ext) ) t(s)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION file_get_contents
 IS 'Gambiarra para ler geojson, até testar a melhor opção com funções nativas pg'
;

CREATE or replace FUNCTION ST_GeomFromGeoJSON_sanitized( p_j  JSONb, p_srid int DEFAULT 4326) RETURNS geometry AS $f$
  SELECT g FROM (
   SELECT  ST_GeomFromGeoJSON(g::text)
   FROM (
   SELECT CASE
    WHEN p_j IS NULL OR p_j='{}'::JSONb OR jsonb_typeof(p_j)!='object'
        OR NOT(p_j?'type')
        OR  (NOT(p_j?'crs') AND (p_srid<1 OR p_srid>998999) )
        OR p_j->>'type' NOT IN ('Feature', 'FeatureCollection', 'Position', 'Point', 'MultiPoint',
         'LineString', 'MultiLineString', 'Polygon', 'MultiPolygon', 'GeometryCollection')
        THEN NULL
    WHEN NOT(p_j?'crs')  OR 'EPSG0'=p_j->'crs'->'properties'->>'name'
        THEN p_j || ('{"crs":{"type":"name","properties":{"name":"EPSG:'|| p_srid::text ||'"}}}')::jsonb
    ELSE p_j
    END
   ) t2(g)
   WHERE g IS NOT NULL
  ) t(g)
  WHERE ST_IsValid(g)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION file_get_contents
 IS $$Do ST_GeomFromGeoJSON() with correct SRID. OLD geojson_sanitize(), as https://gis.stackexchange.com/a/60945/7505$$;


CREATE or replace FUNCTION ST_AsGeoJSONb( -- ST_AsGeoJSON_complete
 -- st_asgeojsonb(geometry, integer, integer, bigint, jsonb
 p_geom geometry,
 p_decimals int default 6,
 p_options int default 1,  -- 1=better (implicit WGS84) tham 5 (explicit)
 p_id text default null,
 p_properties jsonb default null,
 p_name text default null,
 p_title text default null,
 p_id_as_int boolean default false
) RETURNS JSONb AS $f$
 -- Do ST_AsGeoJSON() adding id, crs, properties, name and title
 SELECT ST_AsGeoJSON(p_geom,p_decimals,p_options)::jsonb
        || CASE
           WHEN p_properties IS NULL OR jsonb_typeof(p_properties)!='object' THEN '{}'::jsonb
           ELSE jsonb_build_object('properties',p_properties)
           END
        || CASE
           WHEN p_id IS NULL THEN '{}'::jsonb
           WHEN p_id_as_int THEN jsonb_build_object('id',p_id::bigint)
           ELSE jsonb_build_object('id',p_id)
           END
        || CASE WHEN p_name IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('name',p_name) END
        || CASE WHEN p_title IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('title',p_title) END
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION ST_AsGeoJSONb IS $$
 Enhances ST_AsGeoJSON() PostGIS function.
 Use ST_AsGeoJSONb( geom, 6, 1, osm_id::text, stable.element_properties(osm_id) - 'name:' ).
 $$;
