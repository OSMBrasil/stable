## Software e metodologia para manutenção

No contexto de gestão, a manutenção do presente repositório,
*git OSM-Stable-BR* (URL canônica [`git.openStreetMap.org.br/stable`](https://github.com/OSMBrasil/stable)),
demanda operações de git e de banco de dados.

Na pasta `/src/manut`  encontram-se apenas scripts de manutenção,
mas  pode ser necessário consultar ou rodar algum script de instalação (`/src/install`).

## Transição de teste para stable

```sh
#  após pg_dump -s br osms2_stable | gzip > /tmp/osms_stable-br-$date.sql.gz
psql _etc_ -c "DROP DATABASE osm_br_stable"
psql _etc_ -c "CREATE DATABASE osm_br_stable WITH TEMPLATE osm_br_testing"
```



