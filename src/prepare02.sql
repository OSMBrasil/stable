
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

