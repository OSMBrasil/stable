
# after CREATE DATABASE pgsnapshot;
# after install postgresql v10+, postgis v2+, etc. install osm2pgsql

psql postgres://postgres:myPass@localhost:5432/pgsnapshot -c "CREATE EXTENSION hstore; CREATE EXTENSION postgis;"

osm2pgsql -E 4326 -c -d pgsnapshot -U postgres -W -H localhost --slim --hstore --extra-attributes --hstore-add-index --multi-geometry --number-processes 4 --style /usr/local/share/osm2pgsql/empty.style /root/sandbox/brazil-latest.osm.pbf

