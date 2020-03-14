--
-- Do once. DANGER.  Convert planet_osm_* hstore columns to JSONb, and sanitize tags.
-- Rodar na base "osms0_lake" para depois exportar o stable limpo na base "osm1_test"
--

ALTER TABLE planet_osm_rels ALTER COLUMN members
  TYPE jsonb USING  jsonb_object(members)
; -- fazer o com update até estar seguro. Depois trocar por stable.osmmembers_pack(jsonb_object(members));
ALTER TABLE planet_osm_rels ALTER COLUMN tags TYPE jsonb USING stable.osm_to_jsonb(tags);

-- demora 15 min:
ALTER TABLE planet_osm_line ALTER COLUMN tags TYPE jsonb USING stable.osm_to_jsonb(tags);
ALTER TABLE planet_osm_ways ALTER COLUMN tags
  TYPE jsonb USING jsonb_strip_nulls( stable.osm_to_jsonb(tags), true )
; -- ~10 min
ALTER TABLE planet_osm_polygon ALTER COLUMN tags TYPE jsonb USING stable.osm_to_jsonb(tags);


-- Opcional LIXO:
/* deu pau, anulando 'name:' ... revisar depois quando for usar.
UPDATE planet_osm_polygon -- ~10 minutos. 4.396.944 linhas.
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls(tags,true));
UPDATE planet_osm_line   --  ~9 minutos. 3.869.230 linhas
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls(tags,true));
UPDATE planet_osm_rels   --  ~1 minuto. 151.288 linhas
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls(tags,true));
*/

UPDATE planet_osm_polygon SET tags = jsonb_strip_nulls(tags,true);
UPDATE planet_osm_rels    SET tags = jsonb_strip_nulls(tags,true);


-- NEXT:  02-4-lib, que usa JSONb.
