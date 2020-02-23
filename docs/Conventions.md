# Convenções adotadas

Neste documento são descritas as convenções adotadas no projeto.

## Referência estável 
Ver https://github.com/OSMBrasil/stable/blob/master/brazil-latest.osm.md

## Nomes de banco de dados

Convenções para nomes e papeis nos bancos de dados.  O **Projeto OSM-Stable-BR** demanda a utilização de infraestrutura [PostgreSQL](https://en.wikipedia.org/wiki/PostgreSQL), [PostGIS](https://en.wikipedia.org/wiki/PostGIS) e [PostgREST](http://postgrest.org/en/v6.0/), onde poderá, eventualmente, conviver com outros projetos OSM-Stable (no _namespace_ adota-se o prefixo `osms`). Além disso, do ponto de vista metodológico, é requerido certo grau de encapsulamento. 

Tendo isso em vista, os nomes de bases (utilizados em `CREATE DATABASE nome_de_uma_base`) precisam ser controlados, respeitando-se as seguintes regras, finalidades e justificativas:

Banco | Descrição | Justificativa
------|-----------|------
**`osms0_lake`**|Repositório tipo "lake" de [preparo dos dados](https://en.wikipedia.org/wiki/Data_preparation) (ingestão, transformação e validação automática). Pode conter diversos países.|Faz papel de [Data Lake](https://en.wikipedia.org/wiki/Data_lake) para dados brutos (modelo legado) e seu preparo.
**`osms1_testing`**|Repositório rigorosamente organizado, apenas com dados selecionados. Fase *testing*, para estabilização ("quarentena") e validação humana. Requer performance e modelo dados fixado pela projeto OSM-Stable.|Faz papel "testing distribution", ou seja, permite que auditores avaliem os dados novos a tempo de fazer correções. Quando quando houver mais de um país, fará também papel de [Data Warehouse](https://en.wikipedia.org/wiki/Data_warehouse). <br/>O código "1" auxilia na manutenção e, quando preservado, na semântica de códigos (ex. porta PostgREST `3101`).
**`osms2_stable`**|Idem base `osm2_testing`, porém correspondendo à **fase de produção**. Todos os dados foram homologados, aceitos como "estáveis e qualificados".|Requer isolamento. <br/>O código "2" auxilia na manutenção e, quando preservado, na semântica de códigos (ex. porta PostgREST `3102`).

Não existem padrões muito rigoros no OSM, e diversas convenções, principalmente no que se refere às tags, podem variar de país para país. As ferramentas, tais como _OSMose_ e _Osm2pgsql_ são muito flexíveis tornando sua configuração complexa. Além disso algumas delas são conservadoras, não permitindo a adoção de tecnologias "modernas". A _Osm2pgsql_ por exemplo [se recusa a dar a opção JSONb](https://github.com/openstreetmap/osm2pgsql/issues/672). 

No Projeto OSM-Stable  adota-se a filosofia [*"Convention over configuration"*](https://en.wikipedia.org/wiki/Convention_over_configuration), e um modelo dados baseado em _Osm2pgsql_  e  representações JSONb controladas. As funções de exportação de dados do OSM-Stable, para seu repositório *git*, também são padronizadas. Foram adotados os formatos GeoJSON para geometrias e formato CSV para dados cadastrais, com representação de ponto Geohash.

