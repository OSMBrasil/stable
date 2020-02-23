DROP TABLE IF EXISTS stable.member_of CASCADE;
CREATE TABLE stable.member_of(
  osm_owner bigint NOT NULL, -- osm_id of a relations
  osm_type char(1) NOT NULL, -- from split
  osm_id bigint NOT NULL, -- from split
  member_type text,
  UNIQUE(osm_owner, osm_type, osm_id)
);
CREATE INDEX stb_member_idx ON stable.member_of(osm_type, osm_id);

---

CREATE or replace FUNCTION stable.osm_to_jsonb_remove() RETURNS text[] AS $f$
   SELECT array['osm_uid','osm_user','osm_version','osm_changeset','osm_timestamp'];
$f$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION stable.osm_to_jsonb(
  p_input text[], p_strip boolean DEFAULT false
) RETURNS jsonb AS $f$
  SELECT CASE WHEN p_strip THEN jsonb_strip_nulls_v2(x) ELSE x END
  FROM (
    SELECT jsonb_object($1) - stable.osm_to_jsonb_remove()
  ) t(x)
$f$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION stable.osm_to_jsonb(
  p_input public.hstore, p_strip boolean DEFAULT false
) RETURNS jsonb AS $f$
  SELECT CASE WHEN p_strip THEN jsonb_strip_nulls_v2(x) ELSE x END
  FROM (
    SELECT hstore_to_jsonb_loose($1) - stable.osm_to_jsonb_remove()
  ) t(x)
$f$ LANGUAGE sql IMMUTABLE;

/*lixo old
CREATE or replace FUNCTION stable.osm_to_jsonb(text[]) RETURNS JSONb AS $f$
   SELECT jsonb_object($1) - stable.osm_to_jsonb_remove()
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb(hstore) RETURNS JSONb AS $f$
   SELECT hstore_to_jsonb_loose($1) - stable.osm_to_jsonb_remove()
$f$ LANGUAGE SQL IMMUTABLE;
*/

------------

ALTER TABLE planet_osm_rels alter column members
  type jsonb USING  jsonb_object(members)
; -- fazer o com update até estar seguro. Depois trocar por stable.osmmembers_pack(jsonb_object(members));

-- demora 15 min:
ALTER TABLE planet_osm_line alter column tags type jsonb USING stable.osm_to_jsonb(tags);
ALTER TABLE planet_osm_ways alter column tags type jsonb
      USING jsonb_strip_nulls_v2(stable.osm_to_jsonb(tags)); -- ~10 min

-- mais rapidos:
ALTER TABLE planet_osm_polygon alter column tags type jsonb USING stable.osm_to_jsonb(tags);
ALTER TABLE planet_osm_rels alter column tags type jsonb USING stable.osm_to_jsonb(tags);


-- Opcional LIXO:
/* deu pau, anulando 'name:' ... revisar depois quando for usar.
UPDATE planet_osm_polygon -- ~10 minutos. 4.396.944 linhas.
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls_v2(tags));
UPDATE planet_osm_line   --  ~9 minutos. 3.869.230 linhas
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls_v2(tags));
UPDATE planet_osm_rels   --  ~1 minuto. 151.288 linhas
 SET tags = stable.tags_split_prefix(jsonb_strip_nulls_v2(tags));
*/

UPDATE planet_osm_polygon
 SET tags = jsonb_strip_nulls_v2(tags);
UPDATE planet_osm_line
 SET tags = jsonb_strip_nulls_v2(tags);
UPDATE planet_osm_rels
 SET tags = jsonb_strip_nulls_v2(tags);


-- carrega 02-3-lib  e CONTINUA N0 04
