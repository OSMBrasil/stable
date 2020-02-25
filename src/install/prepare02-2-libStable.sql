--
-- schema STABLE
--

CREATE SCHEMA IF NOT EXISTS stable;

-- -- TABLES:

DROP TABLE IF EXISTS stable.member_of CASCADE;
CREATE TABLE stable.member_of(
  osm_owner bigint NOT NULL, -- osm_id of a relations
  osm_type char(1) NOT NULL, -- from split
  osm_id bigint NOT NULL, -- from split
  member_type text,
  UNIQUE(osm_owner, osm_type, osm_id)
);
CREATE INDEX stb_member_idx ON stable.member_of(osm_type, osm_id);

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
-- -- GENERAL FUNCIONS:
--

CREATE or replace FUNCTION stable.osm_to_jsonb_remove() RETURNS text[] AS $f$
   SELECT array['osm_uid','osm_user','osm_version','osm_changeset','osm_timestamp'];
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb(
  p_input text[], p_strip boolean DEFAULT false
) RETURNS jsonb AS $f$
  SELECT CASE WHEN p_strip THEN jsonb_strip_nulls_v2(x) ELSE x END
  FROM (
    SELECT jsonb_object($1) - stable.osm_to_jsonb_remove()
  ) t(x)
$f$ LANGUAGE sql IMMUTABLE;

CREATE or replace FUNCTION stable.osm_to_jsonb(
  p_input public.hstore, p_strip boolean DEFAULT false
) RETURNS jsonb AS $f$
  SELECT CASE WHEN p_strip THEN jsonb_strip_nulls_v2(x) ELSE x END
  FROM (
    SELECT hstore_to_jsonb_loose($1) - stable.osm_to_jsonb_remove()
  ) t(x)
$f$ LANGUAGE sql IMMUTABLE;

