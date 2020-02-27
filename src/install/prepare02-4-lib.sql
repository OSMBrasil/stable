/**
 * Lib of functions and basic structures.
 */

CREATE EXTENSION IF NOT EXISTS PLpythonU; -- untrested Python2, ideal usar py3
CREATE EXTENSION IF NOT EXISTS unaccent; -- for unaccent()
CREATE EXTENSION IF NOT EXISTS fuzzyStrMatch; -- for metaphone() and levenshtein()
-- CREATE EXTENSION IF NOT EXISTS pgCrypto; -- for SHA1 and crc32.
CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SERVER IF NOT EXISTS files FOREIGN DATA WRAPPER file_fdw;

-- lib2-3 CREATE SCHEMA IF NOT EXISTS stable; -- OSM BR Stable

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

DROP TABLE IF EXISTS stable.city_test_names CASCADE;
CREATE TABLE stable.city_test_names AS
  SELECT unnest(
    '{PR/Curitiba,PR/MarechalCandidoRondon,SC/JaraguaSul,SP/MonteiroLobato,MG/SantaCruzMinas,SP/SaoPaulo,PA/Altamira,RJ/AngraReis}'::text[]
  ) name_path
;

-----

CREATE or replace FUNCTION stable.rel_properties(p_osm_id bigint) RETURNS jsonb AS $f$
  SELECT tags || jsonb_build_object('members',members)
  FROM planet_osm_rels r
  WHERE id = abs(p_osm_id)
$f$ LANGUAGE sql IMMUTABLE;


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

/* -- exemplo de uso:
SELECT file_put_contents('/tmp/lixo.json', (
  SELECT jsonb_pretty(stable.rel_properties(id)
       || stable.rel_dup_properties(id,'r',members_md5_int,members) )
  FROM  planet_osm_rels where id=242467
) ); -- não usar COPY pois gera saida com `\n`

-- Exemplo mais complexo: grava propriedades de todas as cidades:
SELECT t1.name_path, t1.id,
 file_put_contents('/tmp/final-'||t1.id||'.json', (
  SELECT
    trim(((
       jsonb_strip_nulls(stable.rel_properties(r1.id)
       || COALESCE(stable.rel_dup_properties(r1.id,'r',r1.members_md5_int,r1.members),'{}'::jsonb) )
    ) -'flag' -'name:' #-'{"members","n_md5"}' #-'{"members","w_md5"}' #-'{"members","n_size"}' #-'{"members","w_size"}' )::text)
    --trim((
    --   jsonb_strip_nulls(stable.rel_properties(r1.id)
    --   || COALESCE(stable.rel_dup_properties(r1.id,'r',r1.members_md5_int,r1.members),'{}'::jsonb) )
    --)::text)
  FROM  planet_osm_rels r1 where r1.id=t1.id
 ) ) -- /selct /file
FROM (
 SELECT *, stable.getcity_rels_id(name_path) id  from stable.city_test_names
) t1, LATERAL (
 SELECT * FROM planet_osm_rels r WHERE  r.id=t1.id
) t2;

---- testes ------------------------
  SELECT
    trim(((
       jsonb_strip_nulls(stable.rel_properties(r1.id)
       || COALESCE(stable.rel_dup_properties(r1.id,'r',r1.members_md5_int,r1.members),'{}'::jsonb) )
    ) -'flag' -'name:' #-'{"members","n_md5"}' #-'{"members","w_md5"}' #-'{"members","n_size"}' #-'{"members","w_size"}' )::text)
  FROM  planet_osm_rels r1 where r1.id IN (297514,297687, 296625, 298450, 315008,298285,185554, 2217370  );
  -- =297514;

  SELECT t1.name_path, t1.id
  FROM (
   SELECT *, stable.getcity_rels_id(name_path) id  from stable.city_test_names
  ) t1, LATERAL (
   SELECT * FROM planet_osm_rels r WHERE  r.id=t1.id
  ) t2;

-----------

SELECT
  trim(((
     jsonb_strip_nulls(stable.rel_properties(r1.id)
     --|| COALESCE(stable.rel_dup_properties(r1.id,'r',r1.members_md5_int,r1.members),'{}'::jsonb) )
  )) -'flag' -'name:' #-'{"members","n_md5"}' #-'{"members","w_md5"}' #-'{"members","n_size"}' #-'{"members","w_size"}' )::text)
FROM  planet_osm_rels r1 where r1.id IN (297514,297687, 296625, 298450, 315008,298285,185554, 2217370  );
-- =297514;

stable.getcity_polygon_geom

-- ERROR:  stack depth limit exceeded
-- HINT:  Increase the configuration parameter "max_stack_depth" (currently 2048kB), after ensuring the platform's stack depth limit is adequate.
-- CONTEXT:  SQL function "rel_dup_properties" during startup
SELECT r1.id, stable.rel_properties(r1.id)  -'flag' -'name:' #-'{"members","n_md5"}' #-'{"members","w_md5"}' #-'{"members","n_size"}' #-'{"members","w_size"}'
FROM  planet_osm_rels r1 where r1.id IN (298450  );

-- */


-------------
SELECT t1.name_path, t1.id,
 file_put_contents('/tmp/final-'||t1.id||'.json', (
  SELECT
    trim(jsonb_pretty((
       jsonb_strip_nulls(stable.rel_properties(r1.id)
       || COALESCE(stable.rel_dup_properties(r1.id,'r',r1.members_md5_int,r1.members),'{}'::jsonb) )
    ) -'flag' -'name:' #-'{"members","n_md5"}' #-'{"members","w_md5"}' #-'{"members","n_size"}' #-'{"members","w_size"}' )::text)
    --trim((
    --   jsonb_strip_nulls(stable.rel_properties(r1.id)
    --   || COALESCE(stable.rel_dup_properties(r1.id,'r',r1.members_md5_int,r1.members),'{}'::jsonb) )
    --)::text)
  FROM  planet_osm_rels r1 where r1.id=t1.id
 ) ) -- /selct /file
FROM (
 SELECT *, stable.getcity_rels_id(name_path) id  from stable.city_test_names
) t1, LATERAL (
 SELECT * FROM planet_osm_rels r WHERE  r.id=t1.id
) t2;



CREATE or replace FUNCTION stable.rel_properties(
  p_osm_id bigint
) RETURNS JSONb AS $f$
  SELECT tags || jsonb_build_object('members',members)
  -- bug  || COALESCE(stable.rel_dup_properties(id,'r',members_md5_int,members),'{}'::jsonb)
  FROM planet_osm_rels
  WHERE id = abs(p_osm_id)
$f$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION stable.way_properties(
   p_osm_id bigint
) RETURNS jsonb  AS $f$
  SELECT tags || jsonb_build_object(
    'nodes',nodes,
    'nodes_md5',LPAD(to_hex(nodes_md5_int),16,'0')
  )  --  || COALESCE(
     --     select from rels!  stable.rel_dup_properties(id,'w',nodes_md5_int,nodes) limit 1
     --     ,'{}'::jsonb )
  FROM planet_osm_ways r
  WHERE id = p_osm_id
$f$ LANGUAGE sql IMMUTABLE;

CREATE or replace FUNCTION stable.element_properties(
  p_osm_id bigint,
  p_osm_type char default NULL
) RETURNS JSONb AS $wrap$
  SELECT CASE
      WHEN ($2 IS NULL AND $1<0) OR $2='r' THEN stable.rel_properties($1)
      ELSE stable.way_properties($1)
    END
$wrap$ LANGUAGE SQL IMMUTABLE;

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

----------

CREATE or replace FUNCTION stable.save_city_polygons(
  p_root text DEFAULT '/tmp/pg_io/data/'
) RETURNS TABLE(city_name text, osm_id bigint, filename text)
    LANGUAGE sql IMMUTABLE
    AS $f$
  SELECT t1.pathname2, t1.id,
   file_put_contents(p_root||t1.pathname2 ||'/municipio.geojson', jsonb_pretty((
    SELECT
       ST_AsGeoJSONb( (SELECT ST_SimplifyPreserveTopology(way,0) FROM planet_osm_polygon WHERE osm_id=-r1.id), 6, 1, 'R'||r1.id::text,
         (jsonb_strip_nulls(stable.rel_properties(r1.id)
         || COALESCE(stable.rel_dup_properties(r1.id,'r',r1.members_md5_int,r1.members),'{}'::jsonb) )
         ) -'flag' -'name:' #-'{"members","n_md5"}' #-'{"members","w_md5"}' #-'{"members","n_size"}' #-'{"members","w_size"}'
      )
    FROM  planet_osm_rels r1 where r1.id=t1.id
   )) ) -- /selct /pretty /file
  FROM (
     SELECT *, stable.getcity_rels_id(ibge_id) id, stable.std_name2unix(name,uf)  pathname2
     FROM  brcodes_city  WHERE ibge_id!=53
  ) t1, LATERAL (
     SELECT * FROM planet_osm_rels r WHERE  r.id=t1.id
  ) t2;
$f$;
