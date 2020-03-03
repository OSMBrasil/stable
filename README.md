## Stable

O Projeto OSM-Stable é uma proposta de [preservação digital](https://en.wikipedia.org/wiki/Digital_preservation) e de [controle de qualidade](https://en.wikipedia.org/wiki/Data_quality) sobre os dados do OpenStreetMap. Estas convenções são descritas na [documentação](http://OSMS.addressforall.org).

Atualmente, 2020, ainda é um projeto experimental e em desenvolvimento. Na comunidade local **OSM-Brasil** foi adotada a divisão tradicional do território em Estados e Municípios, e o seguinte **escopo de preservação**:

* Pontos de endereçamento postal: *nodes* ou *relations pontuais* descritivos de endereço postal horizontal.

* Linhas de vias terrestres e hidrovias: *ways* ou *relations lineares* descritivos das "roads" do mapa, qualificadas ou citadas em pontos de endereçamento.

* Polígonos de municípios: *relations* descritivas da delimitação oficial dos municípios.

----

Projeto em final de quarententa, com aprovação e participação mínimos da comunidade. 
Neste período a comunidade ainda está convidada a discutir os fundamentos e os rumos do projeto em https://github.com/OSMBrasil/stable/issues 

------

Para auditoria da origem dos dados ou ingestão de novos, ver [`brazil-latest.osm.md`](brazil-latest.osm.md#dump-opensstreetmap-do-brasil).
Para auditoria ou reprodução passo-a-passo do processamento em base de dados SQL,
ver pasta [**src/install**](src/install/README.md#software-de-gestão-do-repositório-stable-br).
Para justificativas de decisões de projeto, ver [Rationale.md](docs/Rationale.md).

Para verificar um exemplo de dados estáveis, ver por exemplo [data/PR/Curitiba](data/PR/Curitiba).

NOTA: teste de visualização da documentação em http://addressforall.org/osms


