## JUSTIFICATIVAS

Memorial resumido das **justificativas técnicas** para as decisões do *projeto OSM-BR-stable*. 
A seguir cada seção ou seção/subseção corresponde a uma justificativa.

## Fonte de metadados do município
A fonte [datasets.ok.org.br/city-codes](http://datasets.ok.org.br/city-codes), baseada em Wikidata, IBGE e OSM tem justificativas
técnicas no seu próprio repositório.

No modelo de dados esta dataset será referido como tabela `brcodes_city` do schema `public`.

## Formato GeoJSON do município
O formato GeoJSON adotado não corresponde apeas a um comando PostGIS, pois satisfaz os seguintes requisitos:

1. Geometria de origem minimamente auditada e confirmada por tags OSM.

2. Formato de saída **GeoJSON** padrão, em conformidade com [RFC&nbsp;7946](https://tools.ietf.org/html/rfc7946);

3. **Geometria estável**, não-suceptível a:

    3.1. mudanças em escala superior a ~2 metros (~7 dígitos de latitude e longitude num ponto dado por *GeoURI default* da [RFC&nbsp;5870](https://tools.ietf.org/html/rfc5870));
    
    3.2. mudanças (ex. edições) que não afetam o operador ST_Equal do PostGIS.

4. Incluir no GeoJSON, `properties`, com base em **metadados** padronizados e estáveis, com origem nas tags OSM e/ou propriedades Wikidata, e em conformidade com a [justificativa acima](#fonte-de-metadados-do-município).

### Requisitos 1 e 2 do GeoJSON do município

No OSM  um município do Brasil,  dentre os ~5,5 mil previstos, além de ter a sua geometria estar expressa por polígono de relation
(sem pontos ou linhas isoladas), requer minimamente as tags `boundary=administrative` e valores consistentes para Wikidata e IBGE
Bom lembrar também que no Brasil todos os seus são _admin_level:8_.
```sql
CREATE VIEW osmc.vwaudit01props_br_city AS
 SELECT -p.osm_id,                            -- precisa ser positivo
        ST_GeometryType(p.way) as geom_type,  -- nao pode ser Collection (nao pode conter pontos isolados da Relation de origem)
        ST_SRID(p.way) as srid,               -- precisa ser 4326
        c.wikidata_id, c.ibge_id              -- não podem ser null
 FROM planet_osm_polygon p LEFT JOIN vw_brcodes_city c -- fornece caches de ID string por JOIN com brcodes_state.
   ON  (p.tags->>'IBGE:GEOCODIGO')::int = c.ibge_id -- AND p.tags?'wikidata'
 WHERE p.tags->>'boundary'='administrative' AND p.tags->>'admin_level'='8'
 ORDER BY 1;
```
Se o projeto [Semantic-bridge](https://github.com/OSMBrasil/semantic-bridge) estiver ativo, pode-se exigir a tag Wikidata.
Independente do resultado da auditoria, para não haver risco de ambiguidade nas consultas, é preciso também garantir a não-duplicidade por

```sql
CREATE VIEW osmc.vwaudit02dups_br_city  AS
 SELECT tags->>'IBGE:GEOCODIGO' as ibge_code, ST_GeometryType(way) as geom_type, count(*) n
 FROM planet_osm_polygon 
 WHERE tags->>'boundary'='administrative' AND tags->>'admin_level'='8' AND tags?'IBGE:GEOCODIGO'
 GROUP BY 1,2
 ORDER BY 1,2
;
-- Estará consistente se:
SELECT count(*) FROM osmc.vwaudit02dups_br_city; --  ~5570 ou conforme IBGE declafrar
SELECT *  FROM osmc.vwaudit02dups_br_city WHERE n>1; --  0 rows
```

### Requisito-3 do GeoJSON do município

O mais importante, por fim, é publicar o polígono do município no _git_ conforme formato mais recomendado.

O limite no número de casas decimais se justifica por [seu significado](https://gis.stackexchange.com/a/8674/7505),
ou seja, não precisamos mais que um metro de precisam nos limites de município, 
já que nem os limites dados por hidrografia ou por definição oficial (IBGE) 
chega a ter essa precisão. Pode-se testar  a sensibilidade da geometria, por exemplo para Boa Vista, por:

```sql
 SELECT ST_AsGeoJSON(way,7)=ST_AsGeoJSON(way,9) AS compare FROM planet_osm_polygon WHERE osm_id=-326286;
```
A simplificação dos pontos preservando a geometria original confere também estabilidade adicional. 
O melhor algoritmo para isso é [ST_SimplifyPreserveTopology(way,tol)](https://postgis.net/docs/ST_SimplifyPreserveTopology.html). 
A verificação de sensibilidade ao parâmetro *tol*, entretanto, deve ser realizada 
com [ST_Equals(g_original,g_simplificada)](https://postgis.net/docs/ST_Equals.html), não com `=`, 
conforme [esta aqui](https://gis.stackexchange.com/q/350299/7505)... Conforme veremos, o melhor é  definir a **geometria stable** como:

```sql
 SELECT ST_AsGeoJSON( ST_SimplifyPreserveTopology(way,0), 7 ) geom 
 FROM planet_osm_polygon WHERE osm_id=-326286;
```

onde a decisão pelo número de dígitos no GeoJSON (7)
e a tolerância na simplificação (tol=0) tem origem em uma análise de sensibilidade para todos os município.

**Verificando a sensibilidade** em todas as geometrias de municípios do Brasil, nos parâmetros *$digs* e *$tol*:
```sql
 SELECT  ST_AsGeoJSON(way,$digs)=ST_AsGeoJSON(way,9) as geojs_cmp, 
         ST_Equals( way, ST_SimplifyPreserveTopology(way,$tol) ) as simp_cmp, 
         count(*) n
 FROM planet_osm_polygon 
 WHERE tags->'boundary'='administrative' AND tags->'admin_level'='8' AND tags?'IBGE:GEOCODIGO'
 GROUP BY 1,2
 ORDER BY 1,2
```
* Zero ocorrências para ambos: `$digs=7` e `$tol=0`
* Limite, onde começam a haver ocorrências: `$digs=6` (mais de 90%) e `$tol=0.00000000001` (menos de 50%).

Portanto os parâmetros escolhidos (7 e 0) são adequados para o presente e o futuro. Outra opção segura seria adotar `$tol=0.000000000005` para reduzir sensibilidade a "falsas modificações" na geometria.

### Requisito-4 do GeoJSON do município

... propriedades eleitas ...

------

## Representação interna na base de dados
Apesar do repositório *stable* ser totalmente independente da tecnologia que se usa para processar os dados, é interessante ressaltar algumas decisões que facilitam o processo de construção e validação dos dados.

A seguir algumas decisões de projeto, baseadas na representação PostgreSQL do OSM, após carga Osm2pgsql: recomenda-se usar *tags* como JSONb ao invés de hStore.

### Uso do modelo Osm2pgsql

Parece ser o software de "conversão de Planet" mais popular e com uma comunidade mais ativa. Em particular, devido à sua relação íntima com o [Nominatim](https://nominatim.openstreetmap.org) e outros projetos que estarão também relacionados ao *stable*. 

### JSONb no Osm2pgsql
Entre as configurações e adaptações do `osm2pgsql`, as principais opções de configuração são já expressas no script [`src/prepare01-1.sh`](src/prepare01-1.sh). Com relação à decisão pelo formato JSONb ao invés do HStore, 

* No github estamos usando pull request com [syncing-a-fork](https://help.github.com/articles/syncing-a-fork)...
* [Performance](http://mateuszmarchel.com/blog/2016/06/29/jsonb-vs-hstore-performance-battle/): *"If you already have hstore field in your table, there is no reason why you should change it to jsonb for performance gain (especially if it's indexed with GIN)"*, mas no osm2pgsql o default é sem GIN, onde perde-se performance e a recomendação final é *"But if you are thinking what type you should choose for your next project - go with jsonb"*

* Recomendação em comunidades de experts: 
   - C. Kerstiens. *"In most cases JSONB is likely what you want when looking for a NoSQL, schema-less, datatype"*; <br/>*"JSONB - In most cases"*; <br/>*"hstore - Can work fine for text based key-value looks, but in general JSONB can still work great here"*, [citusdata.com](https://www.citusdata.com/blog/2016/07/14/choosing-nosql-hstore-json-jsonb/) (2016).<br/>
   - C. Ringer. "it’s probably worth replacing hstore use with jsonb in all new applications" [blog.2ndquadrant](https://blog.2ndquadrant.com/postgresql-anti-patterns-unnecessary-jsonhstore-dynamic-columns/) (2015); "if you're choosing a dynamic structure you should choose jsonb over hstore",  [dba.stackexchange](https://dba.stackexchange.com/questions/115825/jsonb-with-indexing-vs-hstore) (2015).
   - comunidade osm2pgsql:  [issues/692](https://github.com/openstreetmap/osm2pgsql/issues/692) (em aberto), [issues/533](https://github.com/openstreetmap/osm2pgsql/issues/533) (possível reabrir se forem apresentados exemplos concretos).
