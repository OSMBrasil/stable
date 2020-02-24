# editar este script! rodar com "sh file.sh"
echo
echo '# -- ATENÇÃO: leia, copie e cole aqui, e edite deletando estes comentários --'
echo '# pré-requisitos: Postgresql v10+, Postgis v2+, Osm2pgsql'
echo
echo '# -- Rodar o seguinte comando, depois de acertar a sua config para o comando psql:'
echo 'psql postgres://localhost -c "CREATE DATABASE osms0_lake"'
echo 'psql postgres://localhost/osms0_lake -c "CREATE EXTENSION hstore; CREATE EXTENSION postgis;"'
echo
echo '# -- Rodar o seguinte comando, lembrando que pode demorar horas...'
echo 'osm2pgsql -E 4326 -c -d osms0_lake -U myUser -W -H localhost --slim --hstore --extra-attributes --hstore-add-index \'
echo '  --multi-geometry --number-processes 4 --style /usr/local/share/osm2pgsql/empty.style /tmp/brazil-latest.osm.pbf'
echo

