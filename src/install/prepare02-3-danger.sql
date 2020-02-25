--
-- Do once. DANGER.  Convert planet_osm_* hstore columns to JSONb, and sanitize tags. 
--

ALTER TABLE planet_osm_rels alter column members
  type jsonb USING  jsonb_object(members)
; -- fazer o com update até estar seguro. Depois trocar por stable.osmmembers_pack(jsonb_object(members));

-- demora 15 min:
ALTER TABLE planet_osm_line alter column tags type jsonb USING stable.osm_to_jsonb(tags);
ALTER TABLE planet_osm_ways alter column tags type jsonb
      USING jsonb_strip_nulls_v2(stable.osm_to_jsonb(tags)); -- ~10 min

-- mais rapidos:
ALTER TABLE planet_osm_polygon alter column tags type jsonb USING stable.osm_to_jsonb(tags);
ALTER TABLE planet_osm_rels    alter column tags type jsonb USING stable.osm_to_jsonb(tags);


-- Opcional LIXO:
/* deu pau, anulando 'name:' ... revisar depois quando for usar.
UPDATE planet_osm_polygon -- ~10 minutos. 4.396.944 linhas.
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls_v2(tags));
UPDATE planet_osm_line   --  ~9 minutos. 3.869.230 linhas
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls_v2(tags));
UPDATE planet_osm_rels   --  ~1 minuto. 151.288 linhas
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls_v2(tags));
*/

UPDATE planet_osm_polygon SET tags = jsonb_strip_nulls_v2(tags);
UPDATE planet_osm_line    SET tags = jsonb_strip_nulls_v2(tags);
UPDATE planet_osm_rels    SET tags = jsonb_strip_nulls_v2(tags);


-- NEXT:  02-4-lib, que usa JSONb.

