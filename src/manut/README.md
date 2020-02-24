## Software e metodologia para manutenção

No contexto de gestão, a manutenção do presente repositório,
*git OSM-Stable-BR* (URL canônica [`git.openStreetMap.org.br/stable`](https://github.com/OSMBrasil/stable)),
demanda operações de git e de banco de dados.

Na pasta `/src/manut`  encontram-se apenas scripts de manutenção,
mas  pode ser necessário consultar ou rodar algum script de instalação (`/src/install`).

## Transição de teste para stable

Conforme [convenções de nome de base](../../docs/Conventions.md#nomes-de-banco-de-dados) adotadas, e 
aplicando-se boas práticas no uso do PostgreSQL e de backups de segurança,
 
```sh
#  após pg_dump -s br osms2_stable | gzip > /tmp/osms_stable-br-$date.sql.gz
psql _etc_ -c "DROP DATABASE osms2_stable"
psql _etc_ -c "CREATE DATABASE osms2_stable WITH TEMPLATE osms1_testing"
```

