# Convenções adotadas

Nesta seção são descritas as convenções adotadas no projeto.

----

## Apresentação e diretivas

O **Projeto OSM-Stable-BR** demanda a utilização de infraestrutura [PostgreSQL](https://en.wikipedia.org/wiki/PostgreSQL),
[PostGIS](https://en.wikipedia.org/wiki/PostGIS) e [PostgREST](http://postgrest.org/en/v6.0/),
onde poderá, eventualmente, conviver com outros projetos OSM-Stable (no _namespace_ adota-se o prefixo `osms` antes da sigla do país).

Não existem padrões muito rigoros no OSM, e diversas convenções, principalmente no que se refere às tags,
podem variar de país para país. As ferramentas, tais como _OSMose_ e _Osm2pgsql_ são muito flexíveis tornando sua configuração complexa.
Além disso algumas delas são conservadoras, não permitindo a adoção de tecnologias "modernas".
A _Osm2pgsql_ por exemplo [se recusa a dar a opção JSONb](https://github.com/openstreetmap/osm2pgsql/issues/672).

No Projeto OSM-Stable  adota-se a filosofia [*"Convention over configuration"*](https://en.wikipedia.org/wiki/Convention_over_configuration),
e um modelo dados baseado em _Osm2pgsql_  e  representações JSONb controladas.

As funções de exportação de dados do OSM-Stable, para seu repositório *git*, também são padronizadas.
Foram adotados os formatos GeoJSON para geometrias e formato CSV para dados cadastrais, com representação de ponto Geohash.

## Referência estável 

Os metadados da "cópia OSM Planet" ficam registrados no documento da raiz do repositório,
[`brazil-latest.osm.md`](https://github.com/OSMBrasil/stable/blob/master/brazil-latest.osm.md). Softwares de *parsing*  e  *templating* garantem 
a sua expressão consistente em JSON. 

## Nomes de banco de dados

Convenções para nomes e papeis nos bancos de dados.
O **Projeto OSM-Stable-BR** demanda a utilização de infraestrutura [PostgreSQL](https://en.wikipedia.org/wiki/PostgreSQL),
[PostGIS](https://en.wikipedia.org/wiki/PostGIS) e [PostgREST](http://postgrest.org/en/v6.0/),
onde poderá, eventualmente, conviver com outros projetos OSM-Stable (no _namespace_ adota-se o prefixo `osms`).
Além disso, do ponto de vista metodológico, é requerido certo grau de encapsulamento. 

Tendo isso em vista, os nomes de bases (utilizados em `CREATE DATABASE nome_de_uma_base`) precisam ser controlados, respeitando-se as seguintes regras, finalidades e justificativas:

Banco | Descrição | Justificativas
------|-----------|------
**`osms0_lake`**|Repositório tipo "lake" de [preparo dos dados](https://en.wikipedia.org/wiki/Data_preparation) (ingestão, transformação e validação automática). Pode conter diversos países.|Encapsulamento, faz papel de [Data Lake](https://en.wikipedia.org/wiki/Data_lake) para dados brutos (input "as is" do modelo legado) e VIEWS ou funções para exportação ao *testing*.
**`osms1_testing`**|Repositório rigorosamente organizado, nele entram apenas dados do _git branch_ de teste. Fase *testing*, para estabilização ("quarentena") e validação humana.|Encapsulamento, faz papel "testing distribution", ou seja, permite que auditores avaliem os dados novos a tempo de fazer correções. Quando quando houver mais de um país, fará também papel de [Data Warehouse](https://en.wikipedia.org/wiki/Data_warehouse). <br/>O código "1" auxilia na manutenção e, quando preservado, na semântica de códigos (ex. porta PostgREST `3101`).
**`osms2_stable`**|Idem base `osm2_testing`, porém correspondendo à **fase de produção**. Todos os dados foram homologados, aceitos como "estáveis e qualificados".|Requer isolamento, faz papel de entrega final para o uso em produção. <br/>O código "2" auxilia na manutenção e, quando preservado, na semântica de códigos (ex. porta PostgREST `3102`).

## Formatos CSV e GeoJSON 

A ideia do repositório *git* do Projeto OSM-Stable é ser um pouco também de uma **interface para auditoria e visualização dos dados**, principalmente para leigos (não-nerds). E essa auditoria (ou visualização) precisa ser praticável por humanos ("[_human readable_](https://en.wikipedia.org/wiki/Human-readable_medium)")  tanto via Web como via editores e visualizadores de "texto bruto",  o assim-chamado **TXT** (padrão [*plain text*](https://en.wikipedia.org/wiki/Plain_text) com caracters [UTF-8](https://en.wikipedia.org/wiki/UTF-8)).

Em outras palavras, o código-fonte dos dados, que é escrito em formatos abertos tais como JSON, XML ou CSV (todos em substrato TXT) precisam ser legíveis para humanos e máquinas.

Neste sentido cede-se a **demandas mais específicas da infraestrutura** *TXT* e *Web* do *git*:

1. As operações *git* (pull/push) **não podem gerar falsas atualizações**, comprometendo  o repositório. Por exemplo o acréscimo de um espaço em branco entre palavras de um texto em português não altera a informação, portanto causa falsa atualização se for aceito no *git*. Para evitar o problema são adotadas as seguintes **convenções**:

    1.1. O "sistema operacional de referência"  **é o Linux**, onde é adotado como padrão de [*newline*](https://en.wikipedia.org/wiki/Newline#Representation)  **apenas caracter de LF**  (diferente do Windows que é CRLF). Para que o próprio *git* acate a recomendação, usar o arquivo `.gitattributes`.<br/> Na prática isso significa que o *git* irá converter automaticamente as sequências `\r\n` (CR LF), postadas pelo  colaborador Windows, para `\n` (LF).

    1.2. **Não adotar atributo _CRS_** do GeoJSON: a interface Github só aceita o *default*  dado pela omissão, apesar de ser equivalente à declaração explícita de `EPSG:4326` (ou WGS84 ou `urn:ogc:def:crs:EPSG::4326`), gerada inclusive como option no [ST_AsGeoJSON()  do PostGIS](http://www.postgis.net/docs/ST_AsGeoJSON.html).  Omitir o CRS parece ser uma recomendação geral, por exemplo da [rfc5870](https://tools.ietf.org/html/rfc5870).

    1.3. Adotar saídas "JSON pretty" conforme **padrão PostgreSQL, [jsonb_pretty()](https://www.postgresql.org/docs/10/static/functions-json.html#id-1.5.8.20.55)**. É ligeiramente gastona por encher de *newlines*  e espaços... Mas com ela o *git diff*  funciona (!) e usuários não acostumados com JSON (sem plugin no browser) conseguem visualizar o arquivo e as eventuais alterações.

2. Para evitar centenas ou milhares de arquivos numa mesma pasta do repositório, "poluindo" e dificultando o acesso humano através da navegação por pastas, são adotadas as seguintes convenções:

    2.1. **Uma pasta por Estado**, expresso por sua abreviação de UF (unidade federal).

    2.1.1. A pasta contém apenas `README.me` e (opcional) o arquivo GeoJSON, `estado.geojson`, com *mapfeature* controlada (polygon com dados da relation da região administrativa).

    2.2. **Uma pasta por município**, expresso por seu "[nome lex](https://pt.wikipedia.org/wiki/Lex_(URN))" em formato Camel. Por exemplo "São Bernardo do Campo" em URN LEX de jurisdição é `sp;sao.bernardo.campo` que em Camel e adaptada para path fica  `SP/SaoBernardoCampo`.

     2.2.1. A pasta contém `README.me`, o arquivo GeoJSON, `municipio.geojson`, com *mapfeature* controlada (polygon com dados da relation da região administrativa), e subpastas para<!--  lines (tipicamente ruas) e nodes (tipicamente endereços).--> [_map features_](https://wiki.openstreetmap.org/wiki/Map_Features) "oficiais", definidas e controladas pela equipe **curadora do município**.

3. Para respeitar "o grande público", que não vai sequer usar [git GUI desktop](https://git.wiki.kernel.org/index.php/InterfacesFrontendsAndTools#Web_Interfaces) é preciso confiar o repositório a uma boa *"git Web-based Use Interface"* ([git WUI](https://git.wiki.kernel.org/index.php/InterfacesFrontendsAndTools#Web_Interfaces)), que atualmente é a [interface Web Github](https://help.github.com/en/github). **Convenções** adotadas para garantir consistência com a *git WUI*:

    3.1. No JSON de *properties* GeoJSON, **priorizar as chave-valores de primeiro nível**. Justificativa: na visualização do GeoJSON do Github apenas atributos de primeiro nível são visíveis ao se clicar num polígono. 

    3.2. ...


Inicialmente, devido à demanda para prefeituras e aplicações de roteamento, apenas:

* polígonos de delimitações administrativa (cidades e bairros oficiais)
* linhas de logradouros
* pontos de endereçamento (entrada principa do lote ou portão de entidade registrada na Wikidata - parques, hospitais, etc.).
 
Exemplo em planilha amigável com [alguns descritores de ponto de Curitiba](https://docs.google.com/spreadsheets/d/1yKC7ZwS8kU_aHQ1raOau1x3TkmmE074G0Wu7z8XnwzQ/edit#gid=1454207711)

## Elementos do GeoJSON de município

O município é um [sh:GeoShape](https://schema.org/GeoShape) expresso em formato [GeoJSON](https://geojson.org), minimamente contendo os seguintes elementos JSON:

Chave     | Valor
----------|---------
**`id`**          | identificador ([sh:identifier](https://schema.org/identifier)) alfanumérico, letra representando o OSM-type (W=Way, R=Relation).
**`bbox`**          | array com coordenadas da diagonal do retângulo envolvente, **BBOX padrão do GeoJSON**, válido como [sh:box](https://schema.org/box). Canto de baixo depois canto de cima, ambos Lng-Lat.
**`type`**          | Typo de geometria (line, polygon, collection, etc.).
**`properties`**          | objeto JSON com metadados do município.
**`coordinates`** | array de arrays, contendo um [sh:polygon](https://schema.org/polygon).

Os valores de primeiro nível válidos como `properties` do município são:

Chave     | Significado ou valor esperado
----------|--------------
**`name`**          | Nome oficial do município, [sh:name](https://schema.org/name).
**`type`**          | Valor constante, definindo [osm:tag:type=boundary](https://wiki.openstreetmap.org/wiki/Tag:type=boundary).
**`source`** | [osm:&#8203;key:source](https://wiki.openstreetmap.org/wiki/Key:source), indicando o autor do dado (em geral IBGE).
**`boundary`** | Valor constante, definindo [osm:tag:boundary=administrative](https://wiki.openstreetmap.org/wiki/Tag:boundary=administrative).
**`wikidata`** | [osm:&#8203;key&#8203;:wikidata](https://wiki.openstreetmap.org/wiki/Key:wikidata), contendo identificador Wikidata.
**`wikipedia`** | [osm:&#8203;key&#8203;:wikipedia](https://wiki.openstreetmap.org/wiki/Key:wikipedia), contendo rótulo do município na Wikipedia da língua portugesa, em geral `pt:Nome do Município`.
**`admin_level`** | [osm:&#8203;key&#8203;:admin_level](https://wiki.openstreetmap.org/wiki/Key:admin_level) contendo sempre o valor "8", exceto para Brasília.
**`IBGE:GEOCODIGO`** | [osm&#8203;:&#8203;key&#8203;:&#8203;IBGE:GEOCODIGO](https://wiki.openstreetmap.org/wiki/Pt:Key:IBGE:GEOCODIGO) contendo o número do município no padrão IBGE.
**`members`** | objeto JSON definindo, através de arrays, os *identificadores OSM* dos componentes (*map features* Node, Way ou Relation) que se juntaram para formar a geometria.

Exemplo de `members`: 
```json
        "members": {
            "n": {
                "admin_centre": [
                    415523067
                ]
            },
            "w": {
                "outer": [
                    43958163,
                    220383175,
                    242892566,
                    372374865,
                    372374871,
                    372374880,
                    372374883,
                    372374884
                ]
            }
        }
```

Na representação interna do banco de dados pode ainda conter, como *cache* para otimizar velocidade na auditoria, 
as chaves `n_md5` e `w_md5` para controle de casos duplicados.

Ver [exemplo completo de Santa Cruz de Minas](https://raw.githubusercontent.com/OSMBrasil/stable/master/data/MG/SantaCruzMinas/municipio.geojson).
A [visualização do mapa](https://github.com/OSMBrasil/stable/blob/master/data/MG/SantaCruzMinas/municipio.geojson) deve permitir também a
visualização dos atributos, através por exemplo de clique sobre o polígono,
e minimamente os atributos do primeiro nivel da árvore JSON.

![](https://raw.githubusercontent.com/OSMBrasil/stable/master/assets/geojson-municipio-view.png)

