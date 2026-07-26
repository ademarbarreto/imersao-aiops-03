# Contrato de containerização — verificado no código em 2026-07-26

Tudo abaixo foi lido no código, não reproduzido de memória.

## Escuta e endpoints

| Fato | Local | Valor |
|---|---|---|
| Porta de escuta | `src/server.js:81` | `8080`, literal em `app.listen(8080)`. **Não existe variável `PORT`** |
| Liveness | `src/system-life.js:22` | `GET /health` → `{state:'up', machine:<hostname>}`. Não toca no banco |
| Readiness | `src/system-life.js:11` | `GET /ready` → 200 ou 500, controlado por `PUT /unreadyfor/:seconds` |
| Caos | `src/system-life.js:30,36` | `PUT /unhealth` liga o middleware `healthMid`, que passa a responder 500 em **toda** rota |
| Métricas | `src/server.js:9-21` | `/metrics` via `express-prom-bundle` |

## Variáveis de ambiente e defaults

Todas em `src/models/post.js:8-13`. Não há nenhuma outra variável lida em lugar nenhum do código.

| Variável | Default |
|---|---|
| `DB_DATABASE` | `kubedevnews` |
| `DB_USERNAME` | `kubedevnews` |
| `DB_PASSWORD` | `Pg#123` |
| `DB_HOST` | `localhost` |
| `DB_PORT` | `5432` |
| `DB_SSL_REQUIRE` | comparado com a **string** `'true'` (`strToBool`); qualquer outro valor desliga SSL |

Consequência para o ambiente local: espelhar todos os defaults e alterar **apenas** `DB_HOST`.

## Caminhos relativos ao diretório de trabalho

| Caminho | Local | Resolve por |
|---|---|---|
| `static/` | `src/server.js:24` — `express.static('static')` | `process.cwd()` |
| `views/` | `src/server.js:27` — `app.set('view engine','ejs')`, sem `app.set('views', …)` | `process.cwd() + '/views'` (default do Express) |

`src/static/` e `src/views/` existem no repositório. **Derivação:** o conteúdo de `src/` precisa ser a raiz do `WORKDIR` da imagem — `COPY src/ ./` com `WORKDIR /app`, nunca `COPY . .`. Um `WORKDIR` errado não quebra o boot: a aplicação sobe, `/health` responde 200, e só os estáticos e as páginas falham.

## Encerramento por dependência ausente no boot

`src/server.js:80` chama `models.initDatabase()` e **descarta a promise**; `src/models/post.js:58-60` faz `seque.sync({alter:true})` sem `.catch()`. Banco fora no boot → rejeição não tratada → o processo termina com código diferente de zero.

Nenhuma probe cobre isso: `startupProbe` trata boot **lento**, não boot que **termina**. O contorno é ordenar o start em cada ambiente — `depends_on: condition: service_healthy` no Compose, `initContainer` com `pg_isready` no Kubernetes.

## Divergências encontradas contra a documentação existente

| # | Onde | O que diz | O que o código/repo diz |
|---|---|---|---|
| D-1 | `CLAUDE.md`, seção "Comandos" | "Build de imagem para o EKS **exige** `--platform linux/amd64`" | Passa a ser falso com a imagem multiplataforma (D1 do design). Corrigido na tarefa 11.4 |
| D-2 | `CLAUDE.md`, seção "Estado do working tree" | `Dockerfile`, `k8s/` e `terraform/` "existem em `HEAD`" | Não existem: `git show HEAD:Dockerfile` falha. O último commit os removeu. Corrigido na tarefa 11.5 |
| D-3 | `docs/runbook-deploy-kubernetes.md:81` | "`--platform linux/amd64` não é opcional" | Mesma correção de D-1. Tarefas 11.1 e 11.2 |
| D-4 | `docs/runbook-deploy-kubernetes.md:252` | `initContainer` usa `postgres:16-alpine` | A versão adotada é `18-alpine` (D9 do design). Tarefa 11.3 |
| D-5 | `CLAUDE.md`, "Contrato da aplicação" | "o processo **sai com exit 1**" | Preciso na consequência, impreciso no mecanismo: não há `process.exit(1)`; é rejeição não tratada, que o Node encerra com código diferente de zero. Sem impacto prático — mantido |

Fora essas cinco, `CLAUDE.md` e o runbook batem com o código linha a linha.
