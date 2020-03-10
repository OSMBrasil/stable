## Como gerar pastas e arquivos com o nome correto

Conforme as [convenções do projeto OSM-Stable](../Conventions.md#jurisdicoes-e-nomenclatura) os nomes de pasta e nomes de arquivo devem seguir um padrão. Os comandos abaixo garantem a geração de nomes de pasta e nomes de arquivo consistentes com este padrão de nomemclatura das jurisdições.

```sh
# cria todas as pastas desejadas e dentro do padrão esperado.
psql "postgres://localhost/osm_stable_br" -c "select 'mv /tmp/pg_io/'|| path||'  /opt/gits/OSM/stable/'|| path FROM (SELECT 'data/'||stable.std_name2unix(name,uf) ||'/municipio.geojson' path from  brcodes_city) t" | tail -n +3  > gera_paths3.sh

psql "postgres://localhost/osm_stable_br" -c "select stable.save_city_polygons()" &
sudo sh gera_paths3.sh
cd /opt/gits/OSM/stable
git config core.fileMode false
git add .
git commit -m "Atualizando poligonos de municipios"
git push
```
