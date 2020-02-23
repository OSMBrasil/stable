## Software de gestão do repositório Stable-BR
O presente repositório, *git OSM-Stable-BR* (URL canônica [`git.openStreetMap.org.br/stable`](https://github.com/OSMBrasil/stable)),
tem sua origem no gerenciamento de dados realizado por diversos _softwares_, 
tendo como principais na sua infraestrutura PostgreSQL, PostGIS, Osm2pgsql ([refs](#Referências)).

Para usar todos os scrits desta pasta, sugere-se iniciar pelo *git clone* do repositório.
Os scripts bash [prepare01-1.sh](prepare01-1.sh) e [prepare01-2.sh](prepare01-2.sh) devem rodar em sequência.

O software SQL necessário é instalado a partir de  [prepare02-1-libPub.sql](prepare02-1-libPub.sql), 
tomandose o cuidado de não rodar mais do que uma vez arquivos sufixo "danger" ou "Once", `prepare*-danger.sql`.

## Tutorial passo-a-passo
Passo a passo para fazer carga ou manutenção do *git OSM-Stable-BR*. 
Ver também [manuais de apoio na seção de  Referências](#Referências), e índice dos [docs](../docs/README.md).
Para outros elementos passo-a-passo ou exemplos, 
ver documentação de HowTo: [docs/HowTo cityGeoJSON](../docs/HowTo-cityGeoJSON.md) descreve como extrair o GeoJSON de um município.

### Preâmbulos
A carga inicial do arquivo `brazil-latest.osm` desejado pode ser reproduzida utilizado os metadados e instruções 
de [brazil-latest.osm.md](../brazil-latest.osm.md).

Traga o clone deste repositório para a pasta de sua preferência, aqui supondo `/tmp/gits`, e os demais arquivos (principalmente o PBF) 
para uma pasta temporária de sandbox, aqui supondo `/tmp/sandbox`. 
A seguir todos os comandos de terminal partem da pasta *stable*  clonada:

```bash
# after wget to /tmp/sandbox/brazil-latest.osm.pbf
# after copy/paste this script replacing the myPassword to the real password

psql postgres://postgres:myPassword@localhost -c "CREATE DATABASE osm_stable_br;"

cd /tmp/gits
git clone https://github.com/OSMBrasil/stable.git
cd stable
```

### Base de dados
Supondo o uso de `ssh`  num servidor UBUNTU 18 LTS. Ao rodar o [prepare01-1.sh](prepare01-1.sh) você estará realizando aproximadamente 

```sh
psql postgres://postgres:myPassword@localhost/osm_stable_br  \
     -c "CREATE EXTENSION IF NOT EXISTS hstore; CREATE EXTENSION IF NOT EXISTS postgis;"

osm2pgsql -E 4326 -c -d osm_stable_br -U postgres -W -H localhost --slim --hstore \
   --extra-attributes --hstore-add-index --multi-geometry --number-processes 4 \
   --style /usr/local/share/osm2pgsql/empty.style \
   /tmp/sandbox/brazil-latest.osm.pbf &
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

-----

## Referências

* Osm2pgsql (v1) https://github.com/openstreetmap/osm2pgsql
* PostGIS (v2.5)  https://en.wikipedia.org/wiki/PostGIS
* PostgreSQL (v12) https://en.wikipedia.org/wiki/PostgreSQL

Manuais de apoio sugeridos:
* https://www.mankier.com/1/osm2pgsql (2017) 
* http://www.volkerschatz.com/net/osm/osm2pgsql-usage.html (year?)
* Outros: <br/>[question/13458](https://help.openstreetmap.org/questions/13458/does-planet_osm_roads-of-the-osm2pgsqlschema-contain-all-roads?page=1&focusedAnswerId=13460#13460) cita [antiga lista de tags do osm2pgsql](https://github.com/openstreetmap/osm2pgsql/blob/8bf4e4a9f6eafb4a4c31b6fb6be831983fefc8ce/output-pgsql.c#L90), etc.), que cita [outra parte do osm2pgsql](https://github.com/openstreetmap/osm2pgsql/blob/ed86d635cb0e54252881c766ede90a532e63dca0/output-pgsql.cpp#L125-L128); <br/>[issue 230 cita membros](https://github.com/openstreetmap/osm2pgsql/issues/230).
