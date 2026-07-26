# Grupo 4 — Ambiente local com Docker Compose (executado em 2026-07-26)

| # | Comando | Saída obtida | Veredito |
|---|---|---|---|
| 4.1 | `docker compose config` | `DB_PASSWORD: Pg#123` íntegro; `pg_isready -U kubedevnews -d kubedevnews` | PASSOU |
| 4.2 | `docker compose build` + `docker image ls` | `kube-news:local  275MB` | PASSOU — dentro da faixa 150–300 MB |
| 4.3 | `docker compose up -d` sem `.env` | `ls -a \| grep '^\.env'` → nenhum arquivo; stack subiu | PASSOU — zero-config |
| 4.4 | `docker compose ps` | `db Healthy` → **depois** `app Starting` / `app Started` | PASSOU |
| 4.5 | `docker compose logs app` | `grep -c ECONNREFUSED` → `0`; log vai direto ao `sync({alter:true})` | PASSOU |
| 4.6 | `docker compose exec app id` | `uid=1000(node) gid=1000(node)` | PASSOU — sem privilégio administrativo |
| 4.7 | `docker inspect --format '{{.RestartCount}}'` | `app=0 (healthy)`, `db=0 (healthy)` | PASSOU |
| 4.8 | `curl -i http://localhost:8080/` | `HTTP/1.1 200`, `Content-Length: 1702`, `<title>Kubenews</title>` | PASSOU — conteúdo renderizado, não só status |
| 4.9 | Cada estático da página, status + `Content-Type` | `/img/kubenews-logo.svg` 200 `image/svg+xml`; `/img/no-posts.gif` 200 `image/gif`; `/styles/admin.css` 200 `text/css`; `/styles/main.css` 200 `text/css`; `/post` 200 `text/html` | PASSOU — nenhum `text/html` em `.css` |
| 4.10 | `curl -i /health` e `/ready` | `health: 200`, `ready: 200` | PASSOU |
| 4.11 | `POST /api/post` + leitura + `psql` | API ecoou o registro; página inicial contém `SENTINELA-COMPOSE-4.11`; `psql` retornou `1 \| SENTINELA-COMPOSE-4.11` | PASSOU — caminho app → banco provado no banco |
| 4.12 | `down` + `up -d` (sem `-v`) | Containers **removidos**; volume `kube-news_pgdata18` preservado; sentinela presente após nova subida | PASSOU — recriação, não restart |
| 4.13 | `time docker compose stop` | **0,55 s** | PASSOU — muito abaixo de 10 s; SIGTERM chegou ao processo |
| 4.14 | Remoção do sentinela | contagem antes `1` → `DELETE 1` → contagem depois `0` | PASSOU |

## Achados durante a execução

### A-1 — Postgres 18 mudou o ponto de montagem do dado (corrigido)

**Sintoma:** `dependency failed to start: container kube-news-db-1 is unhealthy`, com o banco em `Restarting`.

**Causa:** a partir da 18, a imagem oficial guarda o dado em subdiretório por versão maior (`/var/lib/postgresql/18/docker`) e o ponto de montagem passou a ser `/var/lib/postgresql`. O compose montava em `/var/lib/postgresql/data`, a convenção válida até a 17.

**Por que importa mais do que parece:** esta falha tem duas faces, e só uma é barulhenta.

- Com dado preexistente de versão anterior, o container **recusa subir** — é o caso que aconteceu aqui, e é o barulhento.
- Com volume vazio, o container **sobe normalmente** e grava em `/var/lib/postgresql/18/docker`, que fica **fora** do volume. Nada falha, nada avisa, e o dado some no primeiro `docker compose down`. Só o teste 4.12 — que recria o container em vez de reiniciá-lo — pegaria isso.

**Correção:** montagem em `/var/lib/postgresql`, com volume de nome novo (`pgdata18`).

### A-2 — Volumes de sessão anterior na máquina (reportados, não removidos)

`kube-news_pgdata` e `kube-news_postgres-data` já existiam na máquina, inicializados por uma versão anterior do Postgres. Nenhum dos dois foi removido: o requisito "Tratamento de conflitos com recursos existentes" proíbe remover dado sem confirmação explícita. O ambiente passou a usar `pgdata18`, e os dois volumes antigos continuam intactos e inspecionáveis.

**Pendência para o responsável:** se os dois volumes antigos forem descartáveis, removê-los com `docker volume rm kube-news_pgdata kube-news_postgres-data`. **Não executado** — decisão do dono do dado.

### A-3 — O risco declarado em D9 não se materializou

As dependências de 2022 (`sequelize` 6.19, `pg` 8.7, `express` 4.18) subiram sem incompatibilidade em Node **v24.18.0** sobre Postgres 18. O `sync({alter:true})` emitiu os `ALTER TABLE` do boot e concluiu. O recuo previsto para Node 22 não foi necessário.
