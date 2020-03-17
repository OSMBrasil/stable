
## Instalação

Tutorial passo-a-passo para a instalação do código-fonte do projeto OSM-Stable e base de dados Planet-Brasil do OSM.

A seguir as instruções de como fazer carga ou manutenção do *git OSM-Stable-BR*.
Para maiores detalhes sobre instalação de componentes, ver também [manuais de apoio na seção de  Referências](#Referências),
e índice dos [docs](https://github.com/OSMBrasil/stable/blob/master/docs).
Para outros elementos passo-a-passo ou exemplos,
ver documentação de HowTo: [cityGeoJSON](cityGeoJSON.md) descreve como extrair o GeoJSON de um município.

### Preâmbulos
A carga inicial do arquivo `brazil-latest.osm` desejado pode ser reproduzida utilizado os metadados e instruções
de [brazil-latest.osm.md](https://github.com/OSMBrasil/stable/blob/master/brazil-latest.osm.md).

Traga o clone deste repositório para a pasta de sua preferência, aqui supondo `/tmp/gits`, e os demais arquivos (principalmente o PBF)
para uma pasta temporária de sandbox, aqui supondo `/tmp/pg_io`.
A seguir todos os comandos de terminal partem da pasta *stable*  clonada:

```bash
# after wget to /tmp/pg_io/brazil-latest.osm.pbf
# after copy/paste this script replacing the myPassword to the real password

psql postgres://postgres:myPassword@localhost -c "CREATE DATABASE osms0_lake;"

cd /tmp/gits
git clone https://github.com/OSMBrasil/stable.git
cd stable
```

### Base de dados
Supondo o uso de `ssh`  num servidor UBUNTU 18 LTS. Ao rodar o [prepare01-1.sh](https://github.com/OSMBrasil/stable/blob/master/src/install/prepare01-1.sh) você estará realizando aproximadamente

```sh
psql postgres://postgres:myPassword@localhost/osms0_lake  \
     -c "CREATE EXTENSION IF NOT EXISTS hstore; CREATE EXTENSION IF NOT EXISTS postgis;"

osm2pgsql -E 4326 -c -d osms0_lake -U postgres -W -H localhost --slim --drop --hstore \
   --extra-attributes --hstore-add-index --multi-geometry --number-processes 4 \
   --style /usr/local/share/osm2pgsql/empty.style \
   /tmp/pg_io/brazil-latest.osm.pbf &
```

Depois do comando `osm2pgsql`  (e fornecer a senha quando o terminal solicitar) esperar *online* no terminal, pelo menos 10 minutos...
```
osm2pgsql version 0.96.0 (64 bit id space)

Password:
Using built-in tag processing pipeline
Using projection SRS 4326 (Latlong)
Setting up table: planet_osm_point
...
Setting up table: planet_osm_nodes
Setting up table: planet_osm_ways
Setting up table: planet_osm_rels
Reading in file: ...
Processing: Node(89942k 232.4k/s) Way(8335k 16.15k/s) Relation(1770 68.08/s) ...
```

Depois disso, se correu tudo bem, virá o anúncio *"Using 4 helper-processes"* o que significa que pode fechar o terminal que ele vai rodar em segundo plano (em *batch*). Termina com a seguinte mensagem:
```
Completed planet_osm_line
Creating indexes on planet_osm_polygon finished
All indexes on planet_osm_polygon created in 509s
Completed planet_osm_polygon
Stopped table: planet_osm_ways in 562s

Osm2pgsql took 2636s overall
```
O tempo 2636s equivale a 44 minutos.

## Da base osms0_lake para osms1_testing
Na base `osms0_lake` encontram-se os dados origibais "as is" do OSM, e todos no schema public.
Depois de devidamente transformados (por exemplo script de conversão de hstore para JSONb),
os dados essenciais devem migrar para a base `osms1_testing`.

... Ver https://stackoverflow.com/a/24082105/287948

## Da base osms1_testing para osms2_stable

A troca da base antiga para a nova precisa ocorrer com o menor impacto possível sobre o serviço _online_ das APIs.
Como os _webservices_ apontam para um nome fixo, talvez não tenha problema em fazer DROP DATABASE por alguns minutos, ou durante a madrugada, a cada semestre.
```sql
-- após comando de backup temporário de segurança (para backup oficial ver git)
-- pg_dump osms2_stable | gzip > /tmp/osms2_stable-old.sql.gz
DROP DATABASE osm_br_stable;
CREATE DATABASE osms2_stable WITH TEMPLATE osms1_testing;
```

## Site de documentação 
Usando ferramenta [mkdocs](https://www.mkdocs.org/). Na raiz do projeto rodar por exemplo a construção das paginas no `addressforall.org/osms`:
```sh
sudo mkdocs build -d /var/www/addressforall.org/osms
```
-----

## Referências

* Osm2pgsql (v1) https://github.com/openstreetmap/osm2pgsql
* PostGIS (v2.5)  https://en.wikipedia.org/wiki/PostGIS
* PostgreSQL (v12) https://en.wikipedia.org/wiki/PostgreSQL

Manuais de apoio sugeridos:
* https://www.mankier.com/1/osm2pgsql (2017)
* http://www.volkerschatz.com/net/osm/osm2pgsql-usage.html (year?)
* Outros: <br/>[question/13458](https://help.openstreetmap.org/questions/13458/does-planet_osm_roads-of-the-osm2pgsqlschema-contain-all-roads?page=1&focusedAnswerId=13460#13460) cita [antiga lista de tags do osm2pgsql](https://github.com/openstreetmap/osm2pgsql/blob/8bf4e4a9f6eafb4a4c31b6fb6be831983fefc8ce/output-pgsql.c#L90), etc.), que cita [outra parte do osm2pgsql](https://github.com/openstreetmap/osm2pgsql/blob/ed86d635cb0e54252881c766ede90a532e63dca0/output-pgsql.cpp#L125-L128); <br/>[issue 230 cita membros](https://github.com/openstreetmap/osm2pgsql/issues/230).
