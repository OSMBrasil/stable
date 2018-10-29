/**
 * Lib of functions and basic structures.
 */

CREATE SCHEMA IF NOT EXISTS stable; -- OSM BR Stable

CREATE or replace FUNCTION stable.osm_to_jsonb_remove() RETURNS text[] AS $f$
   SELECT array['osm_uid','osm_user','osm_version','osm_changeset','osm_timestamp'];
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb_remove_prefix(jsonb,text default 'name:') RETURNS text[] AS $f$
  SELECT COALESCE((
    SELECT array_agg(t)
    FROM jsonb_object_keys($1) t
    WHERE position($2 in t)=1
  ), '{}'::text[])
$f$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION stable.osm_to_jsonb(text[]) RETURNS JSONb AS $f$
   SELECT jsonb_object($1) - stable.osm_to_jsonb_remove()
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb(hstore) RETURNS JSONb AS $f$
   SELECT hstore_to_jsonb_loose($1) - stable.osm_to_jsonb_remove()
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.jsonb_members(jsonb) RETURNS jsonb AS $f$
  SELECT jsonb_object_agg(tg,val)
  FROM (
    SELECT v ||'-'||tg as tg, jsonb_agg(val) as val
    FROM (
      SELECT k, v, substr(k,2)::bigint val, substr(k,1,1) as tg
      FROM jsonb_each_text($1) t(k,v)
      ORDER BY 3,2
    ) kv
    GROUP BY 1
  ) t
$f$ LANGUAGE SQL IMMUTAB

---------

DROP TABLE IF EXISTS stable.city_test_names;
CREATE TABLE stable.city_test_names AS
  SELECT unnest(
    '{PR/Curitiba,SC/JaraguaSul,SP/MonteiroLobato,MG/SantaCruzMinas,SP/SaoPaulo,PA/Altamira,RJ/AngraReis}'::text[]
  ) name_path
;

---

CREATE or replace FUNCTION stable.getcity_rels_id(
  p_cod_ibge text  -- código IBGE do município, wikidata-id, lex-name ou path-name
  ,p_admin_level text default '8'
) RETURNS bigint AS $f$
 SELECT id
 FROM planet_osm_rels
 WHERE tags->>'admin_level'=p_admin_level AND CASE
	  WHEN substr(p_cod_ibge,1,1)='Q' THEN p_cod_ibge=tags->>'wikidata' 
	  WHEN substr(p_cod_ibge,3,1) IN (':','-',';') THEN (
	    SELECT "idIBGE"::text FROM mvw_br_city_codes 
	    WHERE upper(substr(p_cod_ibge,1,2))=state AND substr(lower(p_cod_ibge),4)="lexLabel"
	  ) = tags->>'IBGE:GEOCODIGO'
	  WHEN substr(p_cod_ibge,3,1)='/' THEN (
	    SELECT "idIBGE"::text FROM mvw_br_city_codes 
	    WHERE upper(substr(p_cod_ibge,1,2))=state AND substr(p_cod_ibge,4)=stable.lexname_to_path("lexLabel")
	  ) = tags->>'IBGE:GEOCODIGO'
	  WHEN length(p_cod_ibge)=7 THEN p_cod_ibge=tags->>'IBGE:GEOCODIGO'
	  ELSE p_cod_ibge::bigint = (tags->>'IBGE:GEOCODIGO')::bigint
  END
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.getcity_rels_id(
  p_cod_ibge bigint  -- código IBGE do município
  ,p_admin_level text default '8'
) RETURNS bigint AS $wrap$
   SELECT stable.getcity_rels_id($1::text,$2)
$wrap$ LANGUAGE SQL IMMUTABLE;



/*- - 
 select stable.getcity_rels_id('4304408');
 select stable.getcity_rels_id('rS-canEla'); -- case ins.
 select stable.getcity_rels_id('RS/Canela'); -- case sens.
 select stable.getcity_rels_id('Q995318');
 select stable.getcity_rels_id('0004304408');
 select stable.getcity_rels_id('SP/SaoCarlos');
*/

CREATE or replace FUNCTION stable.getcity_polygon_geom(
  p_cod_ibge text  -- código IBGE do município. Completo ou parcial.
  ,p_admin_level text default '8'
) RETURNS geometry AS $f$
 SELECT way
 FROM planet_osm_polygon
 WHERE osm_id = stable.getcity_rels_id(p_cod_ibge,$2)
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.getcity_line_geom(
  p_cod_ibge text  -- código IBGE do município. Completo ou parcial.
  ,p_admin_level text default '8'
) RETURNS geometry AS $f$
 SELECT way
 FROM planet_osm_line
 WHERE -osm_id = stable.getcity_rels_id(p_cod_ibge,$2)
$f$ LANGUAGE SQL IMMUTABLE;

-----

CREATE or replace FUNCTION ST_AsGeoJSONb( -- ST_AsGeoJSON_complete
  p_geom geometry, p_decimals int default 6, p_options int default 3,
  p_id text default null, p_properties jsonb default null, 
  p_name text default null, p_title text default null, 
  p_id_as_int boolean default false
) RETURNS JSONb AS $f$
  -- Do ST_AsGeoJSON() adding id, crs, properties, name and title
  SELECT ST_AsGeoJSON(p_geom,p_decimals,p_options)::jsonb
         || CASE 
              WHEN p_properties IS NULL OR jsonb_typeof(p_properties)!='object' THEN '{}'::jsonb 
              ELSE jsonb_build_object('properties',p_properties) 
            END 
         || CASE
                 WHEN p_id IS NULL THEN '{}'::jsonb WHEN p_id_as_int THEN jsonb_build_object('id',p_id::bigint) 
                 ELSE jsonb_build_object('id',p_id)
            END
         || CASE WHEN p_name IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('name',p_name) END
         || CASE WHEN p_title IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('title',p_title) END
$f$ LANGUAGE SQL IMMUTABLE;

-- readfile, see http://shuber.io/reading-from-the-filesystem-with-postgres/
-- key can be pg_read_file() but no permission
-- ver http://www.postgresonline.com/journal/archives/100-PLPython-Part-2-Control-Flow-and-Returning-Sets.html
-- e https://stackoverflow.com/a/41473308/287948
CREATE OR REPLACE FUNCTION readfile (filepath text)
  RETURNS text
AS $$
 import os
 if not os.path.exists(filepath):
  return "file not found"
 return open(filepath).read()
$$ LANGUAGE plpythonu;


CREATE OR REPLACE FUNCTION read_geojson(
  p_path text,
  p_ext text DEFAULT '.geojson',
  p_basepath text DEFAULT '/opt/gits/city-codes/data/dump_osm/'::text,
  p_srid int DEFAULT 4326
) RETURNS geometry AS $f$
  SELECT CASE WHEN length(s)<30 THEN NULL ELSE geojson_sanitize(s::jsonb) END
  FROM  ( SELECT readfile(p_basepath||p_path||p_ext) ) t(s)
$f$ LANGUAGE SQL IMMUTABLE;

