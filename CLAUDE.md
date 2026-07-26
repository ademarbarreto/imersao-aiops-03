# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este repositório

`kube-news` é um portal de notícias em Node/Express usado como aplicação-alvo de uma imersão de AIOps. O código da aplicação é estável e pequeno; o trabalho real acontece nos artefatos de infraestrutura em volta dele (Docker, Kubernetes, Terraform) e nas skills que codificam o padrão da operação.

## Comandos

Tudo de npm roda **de dentro de `src/`**, não da raiz — o `package.json` vive lá.

```bash
cd src && npm install     # dependências
cd src && npm start       # sobe em http://localhost:8080
```

Não há suíte de testes (`npm test` sai com erro por design). Validação é comportamental: subir a aplicação e exercitar os endpoints. Para popular o banco, use `popula-dados.http` (`POST /api/post` com `{"artigos": [...]}`).

A imagem publicada é **multiplataforma** (`linux/amd64` + `linux/arm64` sob a mesma tag), construída e publicada com `docker buildx build --platform linux/amd64,linux/arm64 --push`. Não existe flag de plataforma a lembrar no build: a classe de falha de arquitetura foi eliminada por construção, não prevenida por disciplina. O procedimento completo está no runbook, Passos 1 e 2.

A tag `v1`, anterior a essa mudança, é **amd64 apenas** — o `exec format error` ainda acontece com ela em node arm64. O manifesto aponta para `v1.0.0`.

## Contrato da aplicação

Estes fatos vêm do código e definem todo manifesto, Dockerfile e compose. Ao alterar a aplicação, refaça esta leitura — configuração que aponta para algo que o código não serve parece certa e evapora no primeiro debug.

| Fato | Onde |
|---|---|
| Porta `8080` hardcoded, **não existe variável `PORT`** | `src/server.js:81` |
| `GET /health` responde só pelo processo, não toca no banco | `src/system-life.js:22` |
| `GET /ready` — prontidão, manipulável por `PUT /unreadyfor/:seconds` | `src/system-life.js:11` |
| `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_SSL_REQUIRE` com defaults | `src/models/post.js:8-13` |
| `sequelize.sync({alter: true})` no boot; o processo **sai com exit 1** se o banco não responder | `src/models/post.js:59` |
| `express.static('static')` e as views EJS resolvem **relativo ao CWD** | `src/server.js:24` |

Três consequências que não são óbvias:

- **A aplicação morre se o banco não estiver de pé no boot.** Nenhuma probe cobre isso: `startupProbe` trata boot lento, não boot que faz `exit 1`. A resposta é `initContainer` com `pg_isready` (no k8s) ou `depends_on: condition: service_healthy` (no compose).
- **`/health` e `/ready` são genuinamente diferentes**, então liveness e readiness têm propósitos distintos de verdade. Liveness nunca deve checar o banco — se checasse, um Postgres lento reiniciaria a frota inteira em cascata.
- **O conteúdo de `src/` precisa virar a raiz do `WORKDIR`** na imagem, porque os caminhos de estático e de views são relativos ao CWD. `COPY src/ ./` com `WORKDIR /app`, não `COPY . .`.

`DB_SSL_REQUIRE` é comparado com a **string** `'true'` (`strToBool` em `src/models/post.js`), então qualquer outro valor desliga SSL.

### Endpoints de caos

`PUT /unhealth` e `PUT /unreadyfor/:seconds` existem para testar probes. Atenção ao `/unhealth`: o middleware `healthMid` fica na frente de todas as rotas, então depois de chamá-lo **toda** requisição passa a responder 500 — não só `/health`. Só um restart do processo desfaz.

## Estrutura de diretórios

Onde cada tipo de artefato mora. Respeite esses destinos ao criar arquivo novo — artefato fora do lugar quebra os comandos do runbook, que referenciam esses caminhos literalmente.

```
/
├── src/          # aplicação Node/Express (o package.json vive aqui, não na raiz)
├── k8s/          # manifestos Kubernetes
├── kind/         # configuração do cluster local de validação do manifesto
├── terraform/    # projeto Terraform — modules/ e environments/
├── docs/
│   ├── prds/     # PRDs (documentos de requisito de produto)
│   └── runbook-deploy-kubernetes.md
└── .claude/skills/   # skills do projeto
```

- **`k8s/`** — manifestos Kubernetes. Hoje é um arquivo único por aplicação (`k8s/kube-news.yaml`, 7 objetos), com a ordem dos documentos importando: Namespace primeiro, config antes dos workloads, banco antes da aplicação (`kubectl apply -f` respeita a ordem do arquivo). Governado pela skill `manifestos-kubernetes`.
- **`terraform/`** — projeto Terraform, na estrutura canônica da skill `terraform-boas-praticas`: `modules/<nome>/` com `{main,variables,outputs,versions}.tf` e `environments/<amb>/` com `{main,variables,versions,providers}.tf` + `terraform.tfvars`. Ambiente novo é pasta nova, nunca workspace.
- **`docs/prds/`** — PRDs. Um arquivo por produto ou feature; é onde o requisito é definido **antes** de virar código ou manifesto. Ao implementar algo que tem PRD, leia o PRD primeiro — ele é a fonte do escopo, e o código é a consequência.

## Estrutura da aplicação

Express monolítico de arquivo único mais três módulos: `src/server.js` (rotas de página e a API de inserção em massa), `src/models/post.js` (Sequelize + o único modelo, `Post`), `src/system-life.js` (router de health/ready e o middleware de caos) e `src/middleware.js` (counter Prometheus). Métricas em `/metrics` via `express-prom-bundle`.

O modelo `Post` tem limites de tamanho validados **na rota**, não no schema: title < 30, summary < 50, content < 2000 (`src/server.js:32-34`). `POST /api/post` não aplica essa validação — ela só existe no formulário.

## Skills do projeto (autoritativas)

`.claude/skills/` traz quatro skills que codificam o padrão da operação. Elas não são sugestão: quando o trabalho cair na área de uma delas, siga-a.

- **`manifestos-kubernetes`** — seis regras inegociáveis para YAML do k8s (requests/limits sempre, liveness e readiness separadas, env só via ConfigMap/Secret, tag fixada, Service coerente, labels e namespace no padrão).
- **`terraform-boas-praticas`** — quatro regras estruturais (módulos próprios, ambientes em pastas e nunca workspace, zero módulos de comunidade, versão de provider consultada no registry antes de escrever).
- **`containerizar-aplicacao`** — fluxo de cinco fases; investigar o contrato antes de escrever qualquer arquivo, validar comportamento depois de subir.
- **`gerar-commit`** — conventional commits em português, a partir do diff em stage.

As três primeiras têm a mesma cláusula de conflito: quando o pedido do usuário contraria uma regra, não execute em silêncio nem recuse — diga em uma frase o que a regra manda e por quê, entregue seguindo a regra, e deixe claro o que ficou diferente do pedido. Se o usuário reafirmar, é decisão dele.

## Runbook de deploy

`docs/runbook-deploy-kubernetes.md` é a fonte da verdade para o deploy no EKS e documenta oito problemas que **aconteceram de verdade** neste projeto — arquitetura de imagem, CrashLoopBackOff por banco ausente no boot, perda de dados sem volume, `EXTERNAL-IP` que demora ~170s até o primeiro `HTTP 200`, ConfigMap alterado sem rollout, entre outros. Consulte-o antes de diagnosticar qualquer coisa no cluster; vários desses sintomas aparecem longe da causa.

Convenções que ele estabelece e que valem para mudanças futuras:

- A senha do banco **não fica no YAML versionado**. O arquivo carrega o placeholder `<DB_PASSWORD>` e o valor entra no pipe: `sed "s|<DB_PASSWORD>|${DB_PASSWORD}|" k8s/kube-news.yaml | kubectl apply -f -`.
- O manifesto usa uma annotation `checksum/config` para forçar rollout quando a config muda. Ao editar o bloco entre os marcadores `# >>> config-hash-inicio` / `# <<< config-hash-fim`, **recalcule o hash e atualize as duas annotations** antes do apply.
- Tag de imagem nunca é reaproveitada. Versão nova → tag nova, e a label `app.kubernetes.io/version` acompanha (mas nunca entra no selector, que é imutável).
- Postgres roda sem volume por decisão explícita de lab, o que exige `strategy: Recreate` no Deployment para não servir dois bancos divergentes durante um rollout.

## Estado do working tree

`Dockerfile`, `.dockerignore`, `docker-compose.yml`, `k8s/kube-news.yaml`, `kind/kind-config.yaml` e `terraform/` existem no working tree, escritos pela mudança `containerizacao-infra-e-deploy`. Eles **não** estão em `HEAD` — o commit `3be1545` removeu os artefatos de infra, e o repositório é refeito por etapa da imersão.

Versões anteriores desses arquivos continuam recuperáveis do histórico, e é onde olhar antes de reescrever qualquer um do zero: `git show 72fd741:Dockerfile`, `git show 72fd741:docker-compose.yml`, `git show b2ff069:k8s/kube-news.yaml`. Elas já seguiam as skills e o runbook, mas trazem versões defasadas (Node 22, Postgres 16, tag `v1` de arquitetura única).

`docs/prds/` já existe, com os três PRDs da imersão.

## Ambiente de validação do manifesto

`k8s/kube-news.yaml` é validado num cluster **kind local**, não na nuvem — `kind/kind-config.yaml` é versionado e fixa `kindest/node:v1.36.1`, a mesma versão menor do EKS de destino (`cluster_version = "1.36"`). O ciclo criar / aplicar / verificar / remover roda em poucos minutos, sem conta em nuvem e sem custo.

Duas regras desse ambiente:

- **O manifesto não é adaptado para o teste passar.** O Service continua `type: LoadBalancer`; quem ganha a capacidade que falta é o ambiente, via `cloud-provider-kind` (que exige `sudo` no macOS). Trocar o tipo do Service validaria um artefato diferente do entregue, e a falha reapareceria só na nuvem.
- **Os nós do kind são arm64.** A validação local exercita justamente a variante de arquitetura que o EKS nunca usa — o que só é possível porque a imagem é multiplataforma.

## MCP

O servidor `kubernetes` está declarado em `.mcp.json` e habilitado. Prefira as ferramentas `mcp__kubernetes__*` a chamar `kubectl` por Bash quando ambas resolverem.
