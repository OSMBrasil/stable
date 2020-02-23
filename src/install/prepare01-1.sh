#
# TROCAR SENHA AQUI DESSE SCRIPT!  replace myPass pela senha correta
#

echo ' -- ATENÇÃO: edite, leia e delete essa linha --'

# ... after install postgresql v10+, postgis v2+, etc. install osm2pgsql
# ... afer DROP DATABASE osm_stable_br

psql postgres://postgres:myPass@localhost -c "CREATE DATABASE osm_stable_br"

psql postgres://postgres:myPass@localhost/osm_stable_br -c "CREATE EXTENSION hstore; CREATE EXTENSION postgis;"

echo ' -- Rodar o seguinte comando, lembrando que pode demorar horas... copie e cole:'
echo
echo 'osm2pgsql -E 4326 -c -d osm_stable_br -U postgres -W -H localhost --slim --hstore --extra-attributes --hstore-add-index --multi-geometry --number-processes 4 --style /usr/local/share/osm2pgsql/empty.style /root/sandbox/brazil-latest.osm.pbf'
