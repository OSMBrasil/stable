# Rodar com "sh file.sh"
# para usar senha trocar conexão "postgres://localhost" por "postgres://myUser:myPass@localhost"

echo
echo '# -- ATENÇÃO: leia, copie e cole aqui, e edite deletando estes comentários --'
echo '# pré-requisitos: prepare01-1.sh'
echo

mkdir -p /tmp/pg_io

wget -O /tmp/pg_io/br_city_codes.csv   -c https://raw.githubusercontent.com/datasets-br/city-codes/master/data/br-city-codes.csv
wget -O /tmp/pg_io/br-region-codes.csv -c https://raw.githubusercontent.com/datasets-br/state-codes/master/data/br-region-codes.csv
wget -O /tmp/pg_io/br-state-codes.csv  -c https://raw.githubusercontent.com/datasets-br/state-codes/master/data/br-state-codes.csv

echo '# RODAR depois de adaptar ao seu psql:'
echo 'psql postgres://localhost/osms0_lake < prepare02-1-libPub.sql'
echo 'psql postgres://localhost/osms0_lake < prepare02-2-lib.sql'



