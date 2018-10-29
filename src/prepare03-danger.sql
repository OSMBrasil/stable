

alter table planet_osm_line alter column tags type jsonb USING stable.osm_to_jsonb(tags);
alter table planet_osm_polygon alter column tags type jsonb USING stable.osm_to_jsonb(tags);
alter table planet_osm_rels alter column tags type jsonb USING stable.osm_to_jsonb(tags);
alter table planet_osm_rels alter column members type jsonb USING stable.jsonb_members(jsonb_object(members));

