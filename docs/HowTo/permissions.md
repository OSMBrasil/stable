## Permissoes nos recursos do projeto

Arquivos e pastas do Projeto OSM-Stable seguem algumas convenções, principalmente no sentido de facilitar o diálogo nos Guias e tutoriais:

* para facilitar o diálogo, supor que todos os repositórios *git* possuem um clone em `/opt/gits/OSM`.

* para facilitar a gestão no NGINX ou Apache, bem como a importação/exportação de arquivos com PostgreSQL, supor que todos tenham acesso ao grupo `www-data`, utilizado na pasta `/var/www` e eventualmente nas pastas `/opt` e `/tmp` conforme adoção de demais regras.

* também para a gestão de importação/exportação de arquivos com PostgreSQL, supor que sempre existe uma pasta `/tmp/pg_io` de propriedade do usuário `postgres`.

Expressando todas as regras em termos de comandos e "boas práticas" (depende do nivel de segurança requerido), supondo terminal bash em ambiente Debian:

```sh
#
# --- PERIGO ao copiar/colar, analise e adapte antes de usar ---
#
# Preparando o user
sudo usermod -aG www-data postgres # dá acesso ao postres para trabalhar com arquivos www-data 
grep ^www-data /etc/group  # root, voce, nginx, apache, e postgres

mkdir -p /tmp/pg_io  # condicional, usar sem medo e sempre, pois /tmp é zerado por boot e outros eventos.

# Preservar owner e padronizar group, dando acesso publico ao git desejado (ideal sob /var/www usar ln -s).
sudo chown -R :www-data /opt/gits
sudo chown -R :www-data /var/www
sudo chown -R :www-data /tmp/pg_io

# garantir permissão de leitura e escrita para todos do grupo, em todas as pastas da convenção adotada:
sudo find /var/www -type f -exec chmod 664 {} \;
sudo find /var/www -type d -exec chmod 775 {} \;

sudo find /opt/gits -type f -exec chmod 664 {} \;
sudo find /opt/gits -type d -exec chmod 775 {} \;

sudo find /tmp/pg_io -type f -exec chmod 664 {} \;
sudo find /tmp/pg_io -type d -exec chmod 775 {} \;
```
