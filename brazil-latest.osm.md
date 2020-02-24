## Dump OpensStreetMap do Brasil
Arquivos utilizados como fonte de dados principal deste repositóiro. 
O download destes arquivos em geral  recebe o rótulo de `brazil-latest.osm`. 
A seguir o histórico e metadados das versões utilizadas, organizadas por data (ano-mês-dia).

* [Mais recente](#2020-01-05)
* [Processo e template](#Template)

## 2018-10-02
Obtido de http://download.geofabrik.de/south-america/brazil-latest.osm.pbf com [_resumo-hash_ MD5](https://en.wikipedia.org/wiki/MD5) confirmada, e os seguites metadados e confirmações no [arquivo PBF](https://wiki.openstreetmap.org/wiki/PBF_Format) de *617 MiB*, auditados por [@ppKrauss](data/data_auditor.csv):

* [_Resumo-hash_ SHA256d](https://en.bitcoin.it/wiki/Protocol_documentation#Hashes): <small><code>477b9c42709f3fd7f5e44dcb38752c1d4f4ef132b2cf39fa1015a742934b42db</code></small>.

* Contagens no [PostgreSQL](https://en.wikipedia.org/wiki/PostgreSQL) após [Osm2pgsql](https://wiki.openstreetmap.org/wiki/Osm2pgsql): 89942954 _nodes_; 8335298 _ways_; 151288 _relations_.

* Metadados extraidos pelo [Osmium](https://osmcode.org/osmium-tool/manual.html):

```
File:
  Name: /root/sandbox/brazil-latest.osm.pbf
  Format: PBF
  Compression: none
  Size: 646507687
Header:
  Bounding boxes:
    (-74.0906,-35.4655,-27.6725,5.5229)
  With history: no
  Options:
    generator=osmium/1.8.0
    osmosis_replication_base_url=http://download.geofabrik.de/south-america/brazil-updates
    osmosis_replication_sequence_number=2024
    osmosis_replication_timestamp=2018-10-02T20:15:02Z
    pbf_dense_nodes=true
    timestamp=2018-10-02T20:15:02Z
Data:
  Bounding box: (-79.5387,-36.9636,-25.7485,15.0024)
  Timestamps:
    First: 2006-02-25T09:18:02Z
    Last: 2018-10-02T20:14:36Z
  Objects ordered (by type and id): yes
  Multiple versions of same object: no
  CRC32: 8e167dd6
  Number of changesets: 0
  Number of nodes:   89942954
  Number of ways:     8335298
  Number of relations: 151288
  Largest changeset ID: 0
  Largest node ID: 5949698908
  Largest way ID: 630023210
  Largest relation ID: 8767041
```

## 2020-01-05
Obtido de http://download.geofabrik.de/south-america/brazil-latest.osm.pbf com [_resumo-hash_ MD5](https://en.wikipedia.org/wiki/MD5) confirmada, e os seguites metadados e confirmações no [arquivo PBF](https://wiki.openstreetmap.org/wiki/PBF_Format) de *846 MiB*, auditados por [@ppKrauss](data/data_auditor.csv):

* [_Resumo-hash_ SHA256d](https://en.bitcoin.it/wiki/Protocol_documentation#Hashes): <small><code>9e424e489380cf77425e110a4bfc6a6dba115469a361a59c1d9ad4ac0f92896d</code></small>.

* Contagens no [PostgreSQL](https://en.wikipedia.org/wiki/PostgreSQL) após [Osm2pgsql](https://wiki.openstreetmap.org/wiki/Osm2pgsql): 131190414 _nodes_; 11090613 _ways_; 203939 _relations_.

* Metadados extraidos pelo [Osmium](https://osmcode.org/osmium-tool/manual.html):

```
File:
  Name: /root/sandbox/brazil-latest.osm.pbf
  Format: PBF
  Compression: none
  Size: 886337300
Header:
  Bounding boxes:
    (-74.0906,-35.4655,-27.6725,5.5229)
  With history: no
  Options:
    generator=osmium/1.8.0
    osmosis_replication_base_url=http://download.geofabrik.de/south-america/brazil-200105.osm.pbf
    osmosis_replication_sequence_number=2484
    osmosis_replication_timestamp=2020-01-05T21:59:02Z
    pbf_dense_nodes=true
    timestamp=2020-01-05T21:59:02Z

Data:
  Bounding box: (-74.5001,-36.9636,-25.7485,15.0024)
  Timestamps:
    First: 2006-02-25T09:18:02Z
    Last: 2020-01-05T21:58:49Z
  Objects ordered (by type and id): yes
  Multiple versions of same object: no
  CRC32: ca5245dd
  Number of changesets: 0
  Number of nodes: 131190414
  Number of ways: 11090613
  Number of relations: 203939
  Largest changeset ID: 0
  Largest node ID: 7110875114
  Largest way ID: 761095754
  Largest relation ID: 10547659
```

----- 

## Template
Os metadados (no _script_ abaixo entre colchetes) podem ser todos obtidos por terminal com os seguintes comandos, a serem adaptados conforme captura:
```bash
# [URL] used by download and MD5 confirmation, in something like
#  wget -c http://download.geofabrik.de/south-america/brazil-latest.osm.pbf
#  wget -c http://download.geofabrik.de/south-america/brazil-latest.osm.pbf.md5
md5sum -c  brazil-latest.osm.pbf.md5  brazil-latest.osm.pbf # MUST confirm to use this template!
ls -lf brazil-latest.osm.pbf # [lsMiB]
openssl dgst -sha256 -binary brazil-latest.osm.pbf | openssl dgst -sha256  # [sha256d]
osmium fileinfo -e brazil-latest.osm.pbf  # [fileinfo_report]
# after all osm2pgsql installation at database "afa_testing"
psql afa_testing -c "SELECT count(*) FROM osm.planet_osm_nodes" # [nodes]
psql afa_testing -c "SELECT count(*) FROM osm.planet_osm_ways"  # [ways]
psql afa_testing -c "SELECT count(*) FROM osm.planet_osm_rels"  # [rels]
```
No terminal DOS Windows o resumo MD5 pode ser calculada por `CertUtil -hashfile ARQUIVO md5`.
Abaixo o código-fonte Markdown para os metadados obtidos:

```markdown
## AAAA-MM-DD
Obtido de ${URL}.osm.pbf com [_resumo-hash_ MD5](https://en.wikipedia.org/wiki/MD5) confirmado, 
e os seguites metadados e confirmações 
no [arquivo PBF](https://wiki.openstreetmap.org/wiki/PBF_Format) de *${lsMiB} MiB*:

* [_Resumo-hash_ SHA256d](https://en.bitcoin.it/wiki/Protocol_documentation#Hashes): <small> `${sha256d}`</small>.

* Contagens banco de dados: ${nodes} _nodes_; ${ways} _ways_; ${rels} _relations_.

* Metadados extraidos pelo [Osmium](https://osmcode.org/osmium-tool/manual.html):

`` ``` ``
${fileinfo_report}
`` ``` ``
```

