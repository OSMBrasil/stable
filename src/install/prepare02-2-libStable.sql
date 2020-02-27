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
