# Converter município para GeoJSON

Todos os municípios podem ser exportados a partir da carga do "OSM-Planet", usando o aplicativo de terminal `osm2pgsql`, 
conforme descrito no [`index.md`](index.md). 
A metodologia de exportação segue as justificativas apresentadas no [`Rationale.md`](../Rationale.md).

A seguir exemplos de localização e verificação, garantindo a qualidade da extração de um município,
para alimentar o presente *git* com seu GeoJSON.

----

## Exemplo de RR-BoaVista no stable 2018 JSON
Pelo [datasets.ok.org.br/city-codes](http://datasets.ok.org.br/city-codes) temos confirmação de que o identificador numérico IBGE é 1400100
e a entrada Wikidata é [Q181056](http://wikidata.org/entity/Q181056#P402), onde fica destacado que 
o [OSM-relation-ID é 326286](https://www.openstreetmap.org/relation/326286).
Ainda assim, convém no SQL conferir se não existem outros polígonos de _boundary:administrative_
com mesmo código IBGE. Na consulta SQL também vale destacar elementos de confusão:
* o identificador  `osm_id` de *relation* é negativo, para destacar de polígono originado por *way* (na Wikidata é positivo).
* o polígono (eventualmente multipolígono) não contem objetos estranhos, apesar da relation OSM e sua visualização no `http://OSM.org` apresentarem um ponto central na geometria (admin_centre).<br/> O conversor `osm2pgsql` garante que não haja mistura (não gera geometria tipo Collection).

```sql
 SELECT osm_id, ST_GeometryType(way) as geom_type, tags 
 FROM planet_osm_polygon 
 WHERE tags->>'boundary'='administrative' and tags->>'IBGE:GEOCODIGO'='1400100';
```

O resultado confirma que não há duplicação, há apenas um item e com o perfil nas tags e na identificação (`osm_id = -326286`) conforme esperado.

## Exemplo de RR-BoaVista no stable 2020 hstore
Para o caso de não se ter adotado a conversão (recomendada) de HStore para JSONb, e aproveitando dados de 2020 para comparar com 2018.

```sql
 SELECT osm_id, ST_GeometryType(way) as geom_type, tags 
 FROM planet_osm_polygon 
 WHERE tags->'boundary'='administrative' and tags->'IBGE:GEOCODIGO'='1400100';
-- ok confirmado osm_id -326286

CREATE VIEW vw_planet_osm_polygon_count_city  AS
 SELECT tags->'IBGE:GEOCODIGO' as ibge_code, ST_GeometryType(way) as geom_type, count(*) n
 FROM planet_osm_polygon 
 WHERE tags->'boundary'='administrative' AND tags->'admin_level'='8' AND tags?'IBGE:GEOCODIGO'
 GROUP BY 1,2
 ORDER BY 1,2
;
SELECT count(*) FROM vw_planet_osm_polygon_count_city; --  mudou de 5570 para 5568
SELECT *  FROM vw_planet_osm_polygon_count_city WHERE n>1; --  0 rows
```
A mudança se refere ao balanço final de exclusões/inclusões oficiais de municípios no Brasil (? conferir!).

## Polígono as-is e simplificado GeoJSON do município

O mais importante, por fim, é publicar o polígono do município no _git_ conforme [`Rationale.md`](../Rationale.md). 
Já temos a tabela e o osm_id, portanto bastaria exportar o resultado de [ST_AsGeoJSON()](https://postgis.net/docs/ST_AsGeoJSON.html) do polígono.

```sql
 SELECT ST_AsGeoJSON( ST_SimplifyPreserveTopology(way,0), 7 ) geom 
 FROM planet_osm_polygon WHERE osm_id=-326286;
```
a única coisa que falta no JSON é o atributo `properties`  
que requer uso de função da biblioteca [`src/install/prepare02-3-lib.sql`](https://github.com/OSMBrasil/stable/blob/master/src/install/prepare02-3-lib.sql)

...   
   
