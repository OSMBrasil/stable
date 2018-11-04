
#
# Rodar depois de prepare01.sh!
# e TROCAR SENHA AQUI DESSE SCRIPT! replace myPass pela senha correta
#

# conferir... Se deu tudo certo... Senão o mais prático é DROP DATABASE e recomeçar.

echo ' -- ATENÇÃO: edite, leia e delete essa linha --'

wget -O /tmp/br_city_codes.csv   -c https://raw.githubusercontent.com/datasets-br/city-codes/master/data/br-city-codes.csv
wget -O /tmp/br-region-codes.csv -c https://raw.githubusercontent.com/datasets-br/state-codes/master/data/br-region-codes.csv
wget -O /tmp/br-state-codes.csv  -c https://raw.githubusercontent.com/datasets-br/state-codes/master/data/br-state-codes.csv

psql postgres://postgres:myPass@localhost/osm_stable_br < ./prepare02-lib.sql

echo ' -- Para o próximo passo melhor rodar em BAT (com & no final), vai demorar... copie e cole:'

echo 'psql postgres://postgres:myPass@localhost/osm_stable_br < ./prepare03-danger.sql'
