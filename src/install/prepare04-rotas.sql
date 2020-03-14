--
-- Rotas federais e estaduais para cache de geometrias simplificadas.
--

--- nova stored procedure:
CREATE or replace FUNCTION stable.rota_tags2lexname(p_tags jsonb) RETURNS text AS $f$
  SELECT x FROM (
    SELECT stable.name2lex(coalesce(p_tags->>'official_name',p_tags->>'name'),true,true,true)
  ) t(x) WHERE substring(x,1,7) IN ('rodovia','estrada')
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION stable.rota_tags2lexname
  IS 'Normaliza nome de rodovia conforme sintaxe URN LEX.';

--- novas views:

CREATE VIEW stable.vw01item_roads_rota_federal AS
  SELECT ref, count(*) n,
              array_agg(DISTINCT osm_id) AS members_osm_id,
              array_agg(DISTINCT lexname) AS members_lexname
  FROM (
    SELECT osm_id,
                 trim(regexp_split_to_table(tags->>'ref', ';')) AS ref,
                 stable.rota_tags2lexname(tags) AS lexname
    FROM planet_osm_roads
    WHERE tags->>'ref' ~ 'BR\-\d\d\d'
  ) t
  WHERE ref ~ '^BR\-\d\d\d$'
  GROUP BY 1 ORDER BY 1
;
COMMENT ON VIEW stable.vw01item_roads_rota_federal
  IS 'Isola rodovias de federais de planet_osm_roads com rótulo oficial de rota BR.'
;
CREATE MATERIALIZED VIEW stable.mvw01lexname_rota_federal AS
 SELECT * FROM (
  SELECT DISTINCT
     ref AS rota_ref,
     unnest(members_lexname) as lexname
   FROM stable.vw01item_roads_rota_federal
   where members_lexname is not null
  ) t
  where lexname is not null
;
CREATE VIEW stable.vw01lexnames_rota_federal AS
    select rota_ref, array_agg(DISTINCT lexname)  as members_lexname
	from stable.mvw01lexname_rota_federal
	group by 1 order by 1
;
CREATE MATERIALIZED VIEW stable.mvw02geom_roads_rota_federal AS
  SELECT
     f.ref AS rota_ref,
     ST_SimplifyPreserveTopology(
       ST_Union( r.way ),
       0.0000005
     ) AS geom,
    count(*) members_n,
    round( SUM(ST_Length(r.way,true))/1000 ) comprimento_km,
    array_agg(r.osm_id) members_osm_id,
    min(r.osm_id) members_id_min,
    max(r.osm_id) members_id_max,
    (SELECT members_lexname FROM stable.vw01lexnames_rota_federal s  where s.rota_ref=f.ref) as members_lexname
  FROM planet_osm_roads r INNER JOIN (
    SELECT ref, unnest(members_osm_id) osm_id
    FROM stable.vw01item_roads_rota_federal
  ) f
  ON f.osm_id=r.osm_id
  GROUP BY 1
  ORDER BY 1
; -- 156 rotas
COMMENT ON MATERIALIZED VIEW stable.mvw02geom_roads_rota_federal
  IS 'Isola rodovias de federais de planet_osm_roads com rótulo oficial de rota BR.'
;
/*
copy sumario to tm CSV HEADER;

-- depois de git clone --single-branch --branch "test2018-10-02A" stable.git
SELECT file_put_contents( 
       '/tmp/pg_io/_rotas/'||rota_ref||'.geojson',
       jsonb_pretty(
            ST_AsGeoJSON(geom,6)::JSONb
           || jsonb_build_object('properties', jsonb_build_object( 
                'name',rota_ref,                'comprimento_km',comprimento_km,
                'members_osm_id',members_osm_id ',  'members_lexnames',members_lexnames
            ))
       ) -- falta properties
 ) as put 
FROM stable.vw03geom_roads_rota_federal
;
*/
