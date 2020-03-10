--
-- schema STABLE.
-- Rodar na base "osms0_lake" para depois exportar o stable limpo na base "osm1_test"
--

-- FALTA definir onde ficará o Planet!

CREATE SCHEMA IF NOT EXISTS stable;

--
-- -- STRING FUNCIONS:
--
CREATE or replace FUNCTION stable.name2lex_pre(
  p_name       text                  -- 1
  ,p_normalize boolean DEFAULT true  -- 2
  ,p_cut       boolean DEFAULT true  -- 3
  ,p_unaccent  boolean DEFAULT false -- 4
) RETURNS text AS $f$
   SELECT
      CASE WHEN p_unaccent THEN lower(unaccent(x)) ELSE x END
   FROM (
     SELECT CASE WHEN p_normalize THEN stable.normalizeterm2($1,p_cut) ELSE $1 END
    ) t(x)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION stable.name2lex_pre IS 'Pre-processamento de limpeza de name2lex().';

CREATE or replace FUNCTION stable.name2lex(
  p_name       text                  -- 1
  ,p_normalize boolean DEFAULT true  -- 2
  ,p_cut       boolean DEFAULT true  -- 3
  ,p_flag      boolean DEFAULT false -- 4
) RETURNS text AS $f$
  SELECT trim(replace(
    regexp_replace(
      stable.name2lex_pre($1,$2,$3,$4),
      E' d[aeo] | d[oa]s | com | para |^d[aeo] | / .+| [aeo]s | [aeo] |\-d\'| d\'|[\-\' ]',
      '.',
      'g'
    ),
    '..',
    '.'
  ),'.')
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION stable.name2lex IS 'Limpa e converte nome próprio para formato URN LEX BR';
-- stable.name2lex(E'Guarda-chuva d\'Água G\'ente',false,true,true);  -- guarda.chuva.agua.g.ente


CREATE or replace FUNCTION stable.std_name2unix(
  p_name       text                  -- 1
  ,p_state     text DEFAULT ''       -- 2
  ,p_normalize boolean DEFAULT true  -- 3
  ,p_cut       boolean DEFAULT true  -- 4
  ,p_unaccent  boolean DEFAULT true  -- 5
) RETURNS text AS $f$
   SELECT CASE WHEN p_state>'' THEN upper(p_state)||'/' ELSE '' END ||
          stable.lexlabel_to_path( stable.name2lex($1,$3,$4,$5) )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION stable.std_name2unix IS 'constroi path com name2lex() e lexlabel_to_path().';
-- select uf,name,ibge_id, stable.std_name2unix(name,uf) path from  brcodes_city;
--
-- select b.uf, b.name,b.ibge_id, stable.std_name2unix(b.name,uf) path, i.ibge_id
--   from  brcodes_city b    right join ibge2020_mun i ON i.ibge_id=b.ibge_id  where b.ibge_id  is null;
/*

select b.uf, b.name, b.ibge_id,   i."Nome_Município"
  from  brcodes_city b    inner join ibge2020_mun i
  ON i.ibge_id=b.ibge_id
  where stable.std_name2unix(b.name,uf)!=stable.std_name2unix(i."Nome_Município",uf)
;
uf |           name            | ibge_id | Nome_Município CORRETO!
----+---------------------------+---------+-----------------
TO | São Valério da Natividade | 1720499 | São Valério
RN | Campo Grande              | 2401305 | Augusto Severo
RN | Boa Saúde                 | 2405306 | Januário Cicco
BA | Santa Teresinha           | 2928505 | Santa Terezinha


uf | name | ibge_id | path | ibge_id
----+------+---------+------+---------
   |      |         |      | 5300108

DF | Brasília |      53 | DF/Brasilia |

*/


--
-- -- GENERAL FUNCIONS:
--

CREATE or replace FUNCTION stable.osm_to_jsonb_remove() RETURNS text[] AS $f$
   SELECT array['osm_uid','osm_user','osm_version','osm_changeset','osm_timestamp'];
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb(
  p_input text[], p_strip boolean DEFAULT false
) RETURNS jsonb AS $f$
  SELECT CASE WHEN p_strip THEN jsonb_strip_nulls(x,true) ELSE x END
  FROM (
    SELECT jsonb_object($1) - stable.osm_to_jsonb_remove()
  ) t(x)
$f$ LANGUAGE sql IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb(
  p_input public.hstore, p_strip boolean DEFAULT false
) RETURNS jsonb AS $f$
  SELECT CASE WHEN p_strip THEN jsonb_strip_nulls(x,true) ELSE x END
  FROM (
    SELECT hstore_to_jsonb_loose($1) - stable.osm_to_jsonb_remove()
  ) t(x)
$f$ LANGUAGE sql IMMUTABLE;


--
-- code converion
--

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


/* ---- lixo lembretes  -----

keys que ficam no JSON do municipio:
  # cortar   properties: "flag"
"id": "R297514",
"bbox": [..],
"type": "Polygon",
"properties": {
  "name": "Curitiba",
  "type": "boundary",
  "source": "IBGE",
  "members": {...},
  "website": "http://www.curitiba.pr.gov.br/",
  "boundary": "administrative",
  "wikidata": "Q4361",
  "wikipedia": "pt:Curitiba",
  "population": "1848943",
  "admin_level": "8",
  "state_capital": "yes",
  "IBGE:GEOCODIGO": "4106902"
  },
"coordinates": [ ..]
*/

--------------
---FROM lixo.SQL
--
-- depois de tudo!


CREATE MATERIALIZED VIEW mvw_osm_city_roads_inside AS
  SELECT c.osm_id AS city_osm_id, p.osm_id road_osm_id
  FROM vw_osm_city_polygon c INNER JOIN planet_osm_roads p
    ON c.way && p.way AND ST_ContainsProperly(c.way,p.way)
  WHERE not(p.tags?'boundary')
; -- 30 min
CREATE MATERIALIZED VIEW mvw_osm_city_points_inside AS
  SELECT c.osm_id AS city_osm_id, p.osm_id point_osm_id
  FROM vw_osm_city_polygon c INNER JOIN planet_osm_point p
    ON ST_ContainsProperly(c.way,p.way)
  WHERE p.tags?'wikidata' OR (p.tags?'addr:street' AND p.tags?'addr:housenumber')
; -- horas
CREATE MATERIALIZED VIEW stable.mvw_osm_roads_outside AS
  SELECT p.osm_id AS road_osm_id
   FROM planet_osm_roads p
     LEFT JOIN mvw_osm_city_roads_inside m ON p.osm_id = m.road_osm_id
  WHERE m.road_osm_id IS NULL AND NOT p.tags ? 'boundary'
;
-----

----

CREATE MATERIALIZED VIEW mvw_osm_city_polygon_summary AS
  SELECT  -osm_id AS osm_rel_id,  ibge_id, 'Q'||wikidata_id AS wikidata_id, name, uf
         ,round(st_area(way,true)/10000.0)/100 as area_km2
         ,(SELECT COUNT(*) FROM mvw_osm_city_roads_inside  WHERE city_osm_id=v.osm_id) AS roads_inside
         ,(SELECT COUNT(*) FROM mvw_osm_city_points_inside WHERE city_osm_id=v.osm_id) AS points_inside
  FROM vw_osm_city_polygon v
; -- minutos

CREATE MATERIALIZED VIEW mvw_osm_city_roads_inside AS
  SELECT c.osm_id AS city_osm_id, p.osm_id road_osm_id
  FROM vw_osm_city_polygon c INNER JOIN planet_osm_roads p
    ON c.way && p.way AND ST_ContainsProperly(c.way,p.way)
  WHERE not(p.tags?'boundary' OR p.tags->>'ref' ~ '^(?:BR|'||c.uf||')\-\d+')
; -- 30 min

----------------------------------------------
/** NEW FROM https://github.com/OSMBrasil/stable/wiki/Do-banco-testing-para-o-banco-stable-no-PostgreSQL
*/


CREATE or replace FUNCTION stable.geohash_pre(p_geom geometry, p_len int default 3) RETURNS text AS $f$
   -- prefixo de geohash até p_len letras (entrequadrantes no nordeste pode ficar com 'a')
   SELECT  CASE WHEN x='' THEN 'a' ELSE 'x' END
   FROM (SELECT substr(ST_Geohash(p_geom),1,p_len)) t(x)
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.road_prename(p_name text) RETURNS text AS $f$
   -- para usar com tags->'ref', fornece o pre-nome, cortando demais subpartes.
   SELECT replace( substring(p_name from '^[^;,/\-]+\-?[^;,/\-]+') , ' ', '')
$f$ LANGUAGE SQL IMMUTABLE;

CREATE MATERIALIZED VIEW stable.mvw_osm_city_roads_inside AS
  SELECT c.osm_id AS city_osm_id, p.osm_id road_osm_id
  FROM vw_osm_city_polygon c INNER JOIN planet_osm_roads p
    ON c.way && p.way AND ST_ContainsProperly(c.way,p.way)
  WHERE not(p.tags?'boundary')
; -- 30 min
CREATE MATERIALIZED VIEW stable.mvw_osm_city_points_inside AS
  SELECT c.osm_id AS city_osm_id, p.osm_id point_osm_id
  FROM vw_osm_city_polygon c INNER JOIN planet_osm_point p
    ON ST_ContainsProperly(c.way,p.way)
  WHERE p.tags?'wikidata' OR (p.tags?'addr:street' AND p.tags?'addr:housenumber')
; -- horas
CREATE MATERIALIZED VIEW stable.mvw_osm_city_polygon_summary AS
  SELECT  -osm_id AS osm_rel_id,  ibge_id, 'Q'||wikidata_id AS wikidata_id, name, uf
         ,round(st_area(way,true)/10000.0)/100 as area_km2
         ,(SELECT COUNT(*) FROM stable.mvw_osm_city_roads_inside  WHERE city_osm_id=v.osm_id) AS roads_inside
         ,(SELECT COUNT(*) FROM stable.mvw_osm_city_points_inside WHERE city_osm_id=v.osm_id) AS points_inside
  FROM vw_osm_city_polygon v
; -- minutos

----
CREATE VIEW stable.vw01_osm_roads_outside AS
  SELECT p.*
  FROM stable.mvw_osm_roads_outside m INNER JOIN planet_osm_roads p
   ON  m.road_osm_id=p.osm_id
;

CREATE VIEW stable.vw01_osm_roads_city_inside AS
  SELECT  m.city_osm_id, p.*
  FROM stable.mvw_osm_city_roads_inside m INNER JOIN planet_osm_roads p
   ON  m.road_osm_id=p.osm_id
;

CREATE VIEW stable.vw_osm_city_polygon AS
 SELECT p.*, c.*
   FROM (public.vw_brcodes_city_filepath c
   JOIN osm.planet_osm_polygon p
	 ON ((((c.ibge_id)::text = (p.tags ->> 'IBGE:GEOCODIGO')) AND (p.tags ? 'admin_level'))))
;
-- DROP VIEW stable.vw01_osm_roads_city_inside cascade;
CREATE VIEW stable.vw01_osm_roads_city_inside AS --ok
  SELECT m.city_osm_id, c.uf, c.name, p.*
  FROM (stable.mvw_osm_city_roads_inside m
  JOIN planet_osm_roads p ON m.road_osm_id = p.osm_id)
  INNER JOIN vw_osm_city_polygon c ON c.osm_id = m.city_osm_id
;


CREATE or replace FUNCTION stable.save_kx_sumario() RETURNS table(uf text, cp text) AS $f$
  -- before run, check sudo chown -R :postgres /opt/gits
  SELECT uf,  copy_csv(
      'kx_sumario.csv', -- kx pois informação redundante
      format('select * from mvw_osm_city_polygon_summary where uf=%L',uf),
      true,
      '/opt/gits/OSM/stable/data/'|| uf ||'/'
    ) cp
  FROM vw_brcodes_state;
$f$ LANGUAGE SQL IMMUTABLE;


---------------

CREATE or replace FUNCTION stable.rel_properties(
  p_osm_id bigint
) RETURNS JSONb AS $f$
  SELECT tags || jsonb_build_object('members',members)
  -- bug  || COALESCE(stable.rel_dup_properties(id,'r',members_md5_int,members),'{}'::jsonb)
  FROM planet_osm_rels
  WHERE id = abs(p_osm_id)
$f$ LANGUAGE SQL IMMUTABLE;


/**
 * Enhances ST_AsGeoJSON() PostGIS function.
 * Use ST_AsGeoJSONb( geom, 6, 1, osm_id::text, stable.element_properties(osm_id) - 'name:' ).
 */
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

----

CREATE or replace FUNCTION stable.save_city_test_names(
  p_root text DEFAULT '/tmp/'
) RETURNS TABLE(city_name text, osm_id bigint, filename text)
    LANGUAGE sql IMMUTABLE
    AS $f$
  SELECT t1.name_path, t1.id,
   file_put_contents(p_root||replace(t1.name_path,'/','-')||'.json', jsonb_pretty((
    SELECT
       ST_AsGeoJSONb( (SELECT ST_SimplifyPreserveTopology(way,0) FROM planet_osm_polygon WHERE osm_id=-r1.id), 6, 1, 'R'||r1.id::text,
         (jsonb_strip_nulls(stable.rel_properties(r1.id)
         || COALESCE(stable.rel_dup_properties(r1.id,'r',r1.members_md5_int,r1.members),'{}'::jsonb) )
         ) -'flag' -'name:' #-'{"members","n_md5"}' #-'{"members","w_md5"}' #-'{"members","n_size"}' #-'{"members","w_size"}'
      )
    FROM  planet_osm_rels r1 where r1.id=t1.id
   )) ) -- /selct /pretty /file
  FROM (
   SELECT *, stable.getcity_rels_id(name_path) id  from stable.city_test_names
  ) t1, LATERAL (
   SELECT * FROM planet_osm_rels r WHERE  r.id=t1.id
  ) t2;
$f$;
-------=====-----------

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
