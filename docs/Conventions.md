# Convenções

Nesta seção são descritas as **convenções adotadas no projeto**.

----

## Apresentação e diretivas

O **Projeto OSM-Stable-BR** demanda a utilização de infraestrutura [PostgreSQL](https://en.wikipedia.org/wiki/PostgreSQL),
[PostGIS](https://en.wikipedia.org/wiki/PostGIS) e [PostgREST](http://postgrest.org/en/v6.0/),
onde poderá, eventualmente, conviver com outros projetos OSM-Stable (no _namespace_ adota-se o prefixo `osms` antes da sigla do país).

Não existem padrões muito rigoros no OSM, e diversas convenções, principalmente no que se refere às _tags_,
podem variar de país para país. As ferramentas, tais como _OSMose_ e _Osm2pgsql_ são muito flexíveis tornando sua configuração complexa.
Além disso algumas delas são conservadoras, não permitindo a adoção de tecnologias "modernas".
A _Osm2pgsql_ por exemplo [se recusa a dar a opção JSONb](https://github.com/openstreetmap/osm2pgsql/issues/672).

No Projeto OSM-Stable  adota-se a filosofia [*"Convention over configuration"*](https://en.wikipedia.org/wiki/Convention_over_configuration),
e um modelo dados interno baseado em _Osm2pgsql_  e  representações JSONb controladas.

As funções de exportação de dados do OSM-Stable, para seu repositório *git*, também são padronizadas.
Foram adotados os formatos [GeoJSON](https://en.wikipedia.org/wiki/GeoJSON) para geometrias
e [CSV](https://en.wikipedia.org/wiki/Comma-separated_values) para dados cadastrais,
com representação de ponto [Geohash](https://en.wikipedia.org/wiki/Geohash).

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

### Nomes de schemas e tabelas
Na base `osms0_lake` são criados
Schemas presentes em ambas bases, *osms1_testing* e *osms2_stable*:

* _public_: objetos publicados na API do PostgREST. <br/>Não se trata portanto um "_namespace_ de trabalho" como nas bases de dados PostgreSQL usuais, mas de um _namespace_ crítico por afetar o usuário final e as convenções de acesso na API.
<!-- * _osm_: tabelas "as is" do OSM, conforme importadas da base `osms0_lake` após [processo de instalação](HowTo/install.md), com origem no `osm2pgsql` de um arquivo `brazil-latest.osm`.-->
* _lib_: funções de biblioteca de uso geral, mas que não se deve misturar ao public.
* _working_: temporária ou para tarefas específicas.
* _datasets_: tabelas menores com _datasets_ relevantes, tais como [datasets.ok.org.br/city-codes](http://datasets.ok.org.br/city-codes).
* _stable_: todas as tabelas e funções dependentes de tabelas do Projeto OSM-Stable.

Tabelas principais do schema *public*:
* ... ver convenções de publicação final. Datasets menores podem ser publicados diretamente em public

Tabelas principais do schema *datasets*:
* ...

Tabelas principais do schema *stable*:
* ...

Tabelas do schema *osm*: geometrias do OSM, podem também vir com o prefixo  "planet_osm_".
* `osm.br_point`: todos os pontos definidos no OSM, de endereçamento ou não.
* `osm.br_line`: linhas de hidrografia, vias secundárias, trilhas, etc.
* `osm.br_polygon`: polígonos de jurisdições (municípios e estados), bacias hidrográficas e outros.
* `osm.br_roads`: ruas, rodovias, ferrovias, etc.

Prefixos nos nomes, esquemas *public* e *stable*:
* `mvw_*`: prefixo de MATERIALIZED VIEW
* `vwDDdesc_*`: prefixo de VIEW, com DD dois dígitos e desc um menemônico descritivo, antes do nome de tabela ou de relacionamento.

### Nomes e API no schema public
Os _datasets_ expostos através do *schema public* são tabelas e views de menor volume. Dados GeoJSON e acesso a tabelas maiores deve ser realializado através de funções, que na API PostgREST respondem pelo _namespace_ `rpc`.

As APIS estão atualmente configuradas nos seguintes _endpoints_:
*  `api.addressforall.org/osms1`: API PostgREST da base  *osms1_testing*. Tabelas do schema public podem ser recuperadas em formato JSON como `/osms1/{nomeTabela}` ou  `/osms1.json/{nomeTabela}`; ou recuperadas em formato CSV por  `/osms1.csv/{nomeTabela}`.
*  `api.addressforall.org/osms2`: API PostgREST da base  *osms2_stable*. Item API `/osms1`.
*  `api.addressforall.org/osms`: _endpoint_ descritor da API da base  *osms2_stable* para funções mais requisitadas. Por exemplo `/osms.json/br/SP/Campinas` retorna todos os metadados de Campinas, enquanto `/osms.geojson/br/SP/Campinas` o seu mapa. <!-- `/osms.json/br/SP/Campinas/ghs-123` retorna metadados de todos os pontos de interseção entre o Geohash 123 e o polígono de Campinas. -->

## Jurisdições e nomenclatura
Diferentes áreas do mundo pertencem a diferentes países, e o mapeamento OSM sobre uma determinada área é realizado principalmente pela comunidade daquele país. As convenções toponímicas, a língua e as leis de demarcação do território são fixadas pelo pais que detém a jurisdição sobre aquele território, ou as jurisdições tais como estados e municípios, determinadas pela normas do país.

No OSM as jurisdições são marcadas pela *tag* [`boundary=administrative`](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative), e seu nível hierárquico pela [*key* `admin_level`](https://wiki.openstreetmap.org/wiki/Pt:Tag:boundary%3Dadministrative#admin_level). Apesar do nome de cada unidade administrativa ser fixado adequadamente pela *key* `name` ou `official_name`, não há uma convenção para uma versão simplificada do nome, mais útil para a referência em URLs e nomes de arquivo.

No projeto OSM-Stable estão sendo adotadas as convenções de transcrição ortográfica da norma [URN LEX](https://tools.ietf.org/html/draft-spinosa-urn-lex-13#section-7). Além disso a adoção de qualquer outra convenção, no escopo do projeto, prioriza as normas de autoridades da jurisdição. <!-- As normas podem ser citdas conforme sua URN LEX.-->

No Brasil a URN LEX foi officialmente adotada a partir de 2008, quando entrou em vigor o  [padrão LexML do Brasil](https://projeto.lexml.gov.br/documentacao/Parte-2-LexML-URN.pdf).  Nomes de jurisdição são representados sem acento, hifens e apóstrofes ou preposições. Nomes como Machadinho D'Oeste (RO) e  Pingo-d'Água (MG) ficam normalizados para "br;ro;machadinho.oeste" e "br;mg;pingo.agua" respectivamente. Na convenção OSM-Stable esses nomes são mapeados de forma reversível para CamelCase e siglas em maiúsculas, em path Unix: "BR/RO/MachadinhoOeste" e "BR/MG/PingoAgua". A função responsável por esta conversão de nomes próprios é a stable.std_name2unix(). Exemplos:

uf |               name               | ibge_id |             path
---|----------------------------------|---------|-------------------------------
AM | Boca do Acre                     | 1300706 | AM/BocaAcre
AC | Brasiléia                        | 1200104 | AC/Brasileia
RO | Alta Floresta D'Oeste            | 1100015 | RO/AltaFlorestaOeste
RO | Colorado do Oeste                | 1100064 | RO/ColoradoOeste
RO | Espigão D'Oeste                  | 1100098 | RO/EspigaoOeste
RO | Guajará-Mirim                    | 1100106 | RO/GuajaraMirim
RO | Ji-Paraná                        | 1100122 | RO/JiParana
RO | Alto Alegre dos Parecis          | 1100379 | RO/AltoAlegreParecis

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
