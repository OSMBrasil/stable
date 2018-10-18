## Stable

Projeto em quarententa, aguardando aprovação da comunidade.

Por hora Gerando backup GeoJSON dos municípios de teste.

```sql

COPY (SELECT ST_AsGeoJSONb(way,6,3,osm_type||osm_id,tags,name,null,false) FROM vw_municipios_km2_base WHERE id_ibge::int=4208906) 
TO '/tmp/SC-JaraguaSul.geojson';
COPY (SELECT ST_AsGeoJSONb(way,6,3,osm_type||osm_id,tags,name,null,false) FROM vw_municipios_km2_base WHERE id_ibge::int=3531704) 
TO '/tmp/SP-MonteiroLobato.geojson';
COPY (SELECT ST_AsGeoJSONb(way,6,3,osm_type||osm_id,tags,name,null,false) FROM vw_municipios_km2_base WHERE id_ibge::int=4106902) 
TO '/tmp/PR-Curitiba.geojson';
```

Ver pasta src com subsídios.


