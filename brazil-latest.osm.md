## Dump OpensStreetMap do Brasil
Arquivos utilizados como fonte de dados principal deste repositóiro. 
O download destes arquivos em geral  recebe o rótulo de `brazil-latest.osm`. 
A seguir o histórico e metadados das versões utilizadas, organizadas por data (ano-mês-dia).

## 2018-10-02

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

Outros metadados: 

* **SHA1**: f1f23f8c46f617688947386ef3de0c2b3dcd1674

* **osm2pgsql results: <br/>`select count(*) from planet_osm_nodes` = 89942954; <br/>`select count(*) from planet_osm_ways` =  8335298;<br/> `select count(*) from planet_osm_rels` = 151288.


