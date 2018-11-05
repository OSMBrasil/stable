/**
 * Lib of functions and basic structures.
 */

CREATE EXTENSION IF NOT EXISTS PLpythonU; -- untrested Python2, ideal usar py3
CREATE EXTENSION IF NOT EXISTS unaccent; -- for unaccent()
CREATE EXTENSION IF NOT EXISTS fuzzyStrMatch; -- for metaphone() and levenshtein()
-- CREATE EXTENSION IF NOT EXISTS pgCrypto; -- for SHA1 and crc32.
CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SERVER IF NOT EXISTS files FOREIGN DATA WRAPPER file_fdw;

CREATE SCHEMA IF NOT EXISTS stable; -- OSM BR Stable

/*  Conferir se haverá uso posterior, senão bobagem só para inicialização:
CREATE  TABLE stable.element_exists(
   osm_id bigint NOT NULL -- negative is relation
  ,is_node boolean NOT NULL DEFAULT false
  ,UNIQUE(is_node,osm_id)
); -- for use with EXISTS(
   -- SELECT 1 FROM stable.element_exists WHERE is_node=t.x AND osm_id=t.y)
INSERT INTO stable.element_exists(is_node,osm_id)
  SELECT false,-id FROM planet_osm_rels;
INSERT INTO stable.element_exists(is_node,osm_id)
  SELECT false,id FROM planet_osm_ways;
INSERT INTO stable.element_exists(is_node,osm_id)
  SELECT true,id FROM planet_osm_nodes;
*/

CREATE TABLE stable.member_of(
  osm_owner bigint NOT NULL, -- osm_id of a relations
  osm_type char(1) NOT NULL, -- from split
  osm_id bigint NOT NULL, -- from split
  member_type text,
  UNIQUE(osm_owner, osm_type, osm_id)
);
CREATE INDEX stb_member_idx ON stable.member_of(osm_type, osm_id);

CREATE or replace FUNCTION stable.members_pack(
  p_owner_id bigint -- osm_id of a relation
) RETURNS jsonb AS $f$
  SELECT jsonb_object_agg(osm_type,member_types)
         || jsonb_object_agg(osm_type||'_size',n_osm_ids)
         || jsonb_object_agg(osm_type||'_md5', substr(osm_ids_md5,0,17)) --
  FROM (
    SELECT osm_type, SUM(n_osm_ids) n_osm_ids,
           jsonb_object_agg(member_type,osm_ids) member_types,
           md5(array_distinct_sort(array_agg_cat(osm_ids_md5))::text) osm_ids_md5
    FROM (
      SELECT osm_type, member_type,
             count(*) as n_osm_ids,
             jsonb_agg(osm_id ORDER BY osm_id) as osm_ids,
             array_agg(osm_id) as osm_ids_md5
      FROM stable.member_of
      WHERE osm_owner=-$1
      GROUP BY 1,2
    ) t1
    GROUP BY 1
  ) t2
$f$ LANGUAGE SQL IMMUTABLE;

-- SELECT member_type, count(*) n FROM stable.member_of group by 1 order by 2 desc,1;
-- usar os mais frquentes apenas .


---- ---


CREATE or replace FUNCTION stable.lexname_to_path(
  p_lexname text
) RETURNS text AS $f$
  SELECT string_agg(initcap(t),'')
  FROM regexp_split_to_table(p_lexname, E'[\\.\\s]+') t
$f$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION stable.osm_to_jsonb_remove() RETURNS text[] AS $f$
   SELECT array['osm_uid','osm_user','osm_version','osm_changeset','osm_timestamp'];
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb_remove_prefix(
  jsonb,text default 'name:'
) RETURNS text[] AS $f$
  -- retorna lista de tags prefixadas, para subtrair do objeto.
  SELECT COALESCE((
    SELECT array_agg(t)
    FROM jsonb_object_keys($1) t
    WHERE position($2 in t)=1
  ), '{}'::text[])
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.tags_split_prefix(
  jsonb,
  text default 'name:'
) RETURNS jsonb AS $f$
  -- transforma objeto com prefixos em objeto com sub-objectos.
  SELECT ($1-stable.osm_to_jsonb_remove_prefix($1)) || jsonb_build_object($2,(
    SELECT jsonb_object_agg(substr(t1,t2.l+1),$1->t1)
    FROM jsonb_object_keys($1) t1, (select length($2) l) t2
    WHERE position($2 in t1)=1
  ))
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb(text[]) RETURNS JSONb AS $f$
   SELECT jsonb_object($1) - stable.osm_to_jsonb_remove()
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb(hstore) RETURNS JSONb AS $f$
   SELECT hstore_to_jsonb_loose($1) - stable.osm_to_jsonb_remove()
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.member_md5key(
  p_members jsonb, -- input from planet_osm_rels
  p_no_rel boolean DEFAULT false, -- exclude rel-members
  p_w_char char DEFAULT 'w' -- or '' for hexadecimal output.
) RETURNS text AS $f$
  SELECT p_w_char || COALESCE($1->>'w_md5','') || CASE
    WHEN p_no_rel THEN ''
    ELSE 'r' || COALESCE($1->>'r_md5','')
  END
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.member_md5key(
  p_rel_id bigint,
  p_no_rel boolean DEFAULT false -- exclude rel-members
) RETURNS text AS $f$
  SELECT stable.member_md5key(members,p_no_rel)
  FROM planet_osm_rels WHERE id=p_rel_id
$f$ LANGUAGE SQL IMMUTABLE;
/*
select count(*) from (select stable.member_md5key(members,true) g, count(*) from planet_osm_rels group by 1 having count(*)>1) t;
-- =  4761
select count(*) from (select stable.member_md5key(members) g, count(*) from planet_osm_rels group by 1 having count(*)>1) t;
-- =  4752
select count(*) from (
    select parts g, count(*)
    from planet_osm_rels group by 1 having count(*)>1) t;
-- =   917
*/

CREATE or replace FUNCTION stable.members_seems_unpack(
  p_to_test jsonb,  -- the input JSON
  p_limit_tests int DEFAULT 5 -- use NULL to check all
) RETURNS boolean AS $f$
  SELECT substr(k,1,1)~'^[nwr]$' AND  substr(k,2)~'^[0-9]+$'
  FROM jsonb_each_text(p_to_test) t(k,gtype) LIMIT p_limit_tests
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.members_seems_pack(jsonb) RETURNS boolean AS $f$
  SELECT CASE WHEN jsonb_typeof($1)='object' AND (
     SELECT bool_and( jsonb_typeof($1->t) = 'object' )
     FROM (
       VALUES ('n'), ('w'), ('r')
     ) t(t)
   ) THEN true ELSE false END
$f$ LANGUAGE SQL IMMUTABLE;


---

DROP TABLE IF EXISTS stable.city_test_names;
CREATE TABLE stable.city_test_names AS
  SELECT unnest(
    '{PR/Curitiba,SC/JaraguaSul,SP/MonteiroLobato,MG/SantaCruzMinas,SP/SaoPaulo,PA/Altamira,RJ/AngraReis}'::text[]
  ) name_path
;

-----

CREATE or replace FUNCTION stable.rel_dup_properties(
  p_osm_id bigint,
  p_osm_type char,
  p_members_md5_int bigint,
  p_members jsonb,
  p_kname text DEFAULT 'dup_geoms'
) RETURNS JSONb AS $f$
  --  (atualmente 0,1% dos casos pode não estar duplicando relation...)
  SELECT CASE
    WHEN p_kname IS NULL OR x IS NULL THEN x  -- ? x nunca é null
    ELSE jsonb_build_object(p_kname,x)
    END
  FROM (
   -- array de duplicados, eliminando lista de ways e relations já que é duplicada
   SELECT jsonb_agg(x #- '{members,w}' #- '{members,r}') x
   FROM (
    (
      SELECT stable.rel_properties(id) || jsonb_build_object('id','R'||id) x
      FROM planet_osm_rels
      WHERE p_osm_type='r' AND (
      (id != abs(p_osm_id) AND members_md5_int=p_members_md5_int)
      OR
      id = ( -- check case of super-realation of one relation
        SELECT (members->'r'->jsonb_object_1key(members->'r')->>0)::bigint
        FROM planet_osm_rels
        WHERE id=abs(p_osm_id) AND members->>'r_size'='1' AND not(members?'w')
        ) -- /=
      ) -- /AND
    ) -- /select
    UNION
    SELECT stable.way_properties(id)  || jsonb_build_object('id','W'||id) x
    FROM planet_osm_ways
    WHERE
      (p_osm_type='w' AND id != p_osm_id AND nodes_md5_int=p_members_md5_int)
      OR
      id = ( -- check case of realation of one way
        SELECT (members->'w'->jsonb_object_1key(members->'w')->>0)::bigint
        FROM planet_osm_rels
        WHERE p_osm_type='r' AND id=abs(p_osm_id)
          AND members->>'w_size'='1' AND not(members?'r')
      ) -- /=
   ) t1
  ) t2
$f$ LANGUAGE SQL IMMUTABLE;
/* exemplo de uso:
SELECT file_put_contents('/tmp/lixo.json', (
  SELECT jsonb_pretty(stable.rel_properties(id)
       || stable.rel_dup_properties(id,'r',members_md5_int,members) )
  FROM  planet_osm_rels where id=242467
) ); -- não usar COPY pois gera saida com `\n`
*/

CREATE or replace FUNCTION stable.rel_properties(
  p_osm_id bigint
) RETURNS JSONb AS $f$
  SELECT tags || jsonb_build_object('members',members)
  || COALESCE(stable.rel_dup_properties(id,'r',members_md5_int,members),'{}'::jsonb)
  FROM planet_osm_rels
  WHERE id = abs(p_osm_id)
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.way_properties(
  p_osm_id bigint
) RETURNS JSONb AS $f$
  SELECT tags || jsonb_build_object(
    'nodes',nodes,
    'nodes_md5',LPAD(to_hex(nodes_md5_int),16,'0')
  ) || COALESCE(
    select from rels!
    stable.rel_dup_properties(id,'w',nodes_md5_int,nodes),
    '{}'::jsonb
  )
  FROM planet_osm_ways r
  WHERE id = p_osm_id
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.element_properties(
  p_osm_id bigint,
  p_osm_type char default NULL
) RETURNS JSONb AS $wrap$
  SELECT CASE
      WHEN ($2 IS NULL AND $1<0) OR $2='r' THEN stable.rel_properties($1)
      ELSE stable.way_properties($1)
    END
$wrap$ LANGUAGE SQL IMMUTABLE;

/**
 * Enhances ST_AsGeoJSON() PostGIS function.
 * Use ST_AsGeoJSONb( geom, 6, 1, osm_id::text, stable.element_properties(osm_id) - 'name:' ).
 */
CREATE or replace FUNCTION ST_AsGeoJSONb( -- ST_AsGeoJSON_complete
  st_asgeojsonb(geometry, integer, integer, bigint, jsonb
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

/*
-- readfile, see http://shuber.io/reading-from-the-filesystem-with-postgres/
-- key can be pg_read_file() but no permission
-- ver http://www.postgresonline.com/journal/archives/100-PLPython-Part-2-Control-Flow-and-Returning-Sets.html
-- e https://stackoverflow.com/a/41473308/287948
-- e https://stackoverflow.com/a/48485531/287948
CREATE OR REPLACE FUNCTION readfile (filepath text)
  RETURNS text
AS $$
 import os
 if not os.path.exists(filepath):
  return "file not found"
 return open(filepath).read()
$$ LANGUAGE plpythonu;
*/

CREATE or replace FUNCTION file_get_contents(p_file text) RETURNS text AS $$
   with open(args[0],"r") as content_file:
       content = content_file.read()
   return content
$$ LANGUAGE PLpythonU;

CREATE or replace FUNCTION file_put_contents(
  p_file text,
  p_content text,
  p_msg text DEFAULT ' (file "%s" saved!) '
) RETURNS text AS $$
  o=open(args[0],"w")
  o.write(args[1]) # no +"\n", no magic EOL
  o.close()
  if args[2] and args[2].find('%s')>0 :
    return (args[2] % args[0])
  else:
    return args[2]
$$ LANGUAGE PLpythonU;

CREATE or replace FUNCTION ST_GeomFromGeoJSON_sanitized( p_j  JSONb, p_srid int DEFAULT 4326) RETURNS geometry AS $f$
  -- do ST_GeomFromGeoJSON()  with correct SRID.  OLD geojson_sanitize().
  -- as https://gis.stackexchange.com/a/60945/7505
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

CREATE OR REPLACE FUNCTION read_geojson(
  p_path text,
  p_ext text DEFAULT '.geojson',
  p_basepath text DEFAULT '/opt/gits/city-codes/data/dump_osm/'::text,
  p_srid int DEFAULT 4326
) RETURNS geometry AS $f$
  SELECT CASE WHEN length(s)<30 THEN NULL ELSE ST_GeomFromGeoJSON_sanitized(s::jsonb) END
  FROM  ( SELECT file_get_contents(p_basepath||p_path||p_ext) ) t(s)
$f$ LANGUAGE SQL IMMUTABLE;

-- --

CREATE or replace FUNCTION stable.id_ibge2uf(p_id text) REtURNS text AS $$
  -- A rigor deveria ser construida pelo dataset brcodes... Gambi.
  -- Using official codes of 2018, lookup-table, from IBGE code to UF abbreviation.
  -- for general city-codes use stable.id_ibge2uf(substr(id,1,2))
  SELECT ('{
    "12":"AC", "27":"AL", "13":"AM", "16":"AP", "29":"BA", "23":"CE",
    "53":"DF", "32":"ES", "52":"GO", "21":"MA", "31":"MG", "50":"MS",
    "51":"MT", "15":"PA", "25":"PB", "26":"PE", "22":"PI", "41":"PR",
    "33":"RJ", "24":"RN", "11":"RO", "14":"RR", "43":"RS", "42":"SC",
    "28":"SE", "35":"SP", "17":"TO"
  }'::jsonb)->>$1
$$ language SQL immutable;

-- -- -- -- -- --
-- CEP funcions. To normalize and convert postalCode_ranges to integer-ranges:

CREATE or replace FUNCTION stable.csvranges_to_int4ranges(
  p_range text
) RETURNS int4range[] AS $f$
   SELECT ('{'||
      regexp_replace( translate(regexp_replace($1,'\][;, ]+\[','],[','g'),' -',',') , '\[(\d+),(\d+)\]', '"[\1,\2]"', 'g')
   || '}')::int4range[];
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.int4ranges_to_csvranges(
  p_range int4range[]
) RETURNS text AS $f$
   SELECT translate($1::text,',{}"',' ');
$f$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION jsonb_strip_nulls_v2(
  -- on  empty returns null
  p_input jsonb
) RETURNS jsonb AS $f$
   SELECT CASE WHEN x='{}'::JSONb THEN NULL ELSE x END
   FROM (SELECT jsonb_strip_nulls($1)) t(x)
$f$ LANGUAGE SQL IMMUTABLE;
