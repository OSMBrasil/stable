## Software de gestão do repositório Stable-BR
O presente repositório, *git OSM-Stable-BR* (URL canônica [`git.openStreetMap.org.br/stable`](https://github.com/OSMBrasil/stable)),
tem sua origem no gerenciamento de dados realizado por diversos _softwares_,
tendo como principais na sua infraestrutura PostgreSQL, PostGIS, Osm2pgsql ([refs](#Referências)).

Para usar todos os scrits desta pasta, sugere-se iniciar pelo *git clone* do repositório.
Os scripts bash [prepare01-1.sh](prepare01-1.sh) e [prepare01-2.sh](prepare01-2.sh) devem rodar em sequência.

O software SQL necessário é instalado a partir de  [prepare02-1-libPub.sql](prepare02-1-libPub.sql),
tomandose o cuidado de não rodar mais do que uma vez arquivos sufixo "danger" ou "Once", `prepare*-danger.sql`.

## Instalação passo-a-passo

Ver guia completo de instalação na documentação, no [docs/HowTo/install.md](../../docs/HowTo/install.md).

Para entender a organiação geral de bancos de dados e convenções adotadas ver também [docs/Conventions.md](../../docs/Conventions.md).
