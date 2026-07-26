# Relatório de evidências — `containerizacao-infra-e-deploy`

Execução em **2026-07-26**. Uma linha por critério, com o comando executado e a saída obtida.

**Evidência, não adjetivo.** `RESTARTS: 0` prova; "está estável" não. Dimensão não aplicável entra como `n/a` **com a razão**; dimensão não verificada entra como **NÃO VERIFICADA** — item omitido é lido como item aprovado, e por isso nada é omitido.

---

## 13.2 — PRD 001 / Milestone 1: Ambiente local reproduzível

| Critério | Comando | Saída | Veredito |
|---|---|---|---|
| Um único comando, a partir de clone limpo, sobe aplicação e banco sem configuração manual | `docker compose up -d` sem nenhum `.env` | `db Healthy` → `app Started` | **PASSOU** |
| A página inicial responde com sucesso a partir da máquina do usuário | `curl -i http://localhost:8080/` | `HTTP/1.1 200`, `Content-Length: 1702`, `<title>Kubenews</title>` | **PASSOU** |
| Todos os recursos estáticos respondem com sucesso e com o tipo de conteúdo correto | `curl` em cada recurso da página | `.svg` → `image/svg+xml`, `.gif` → `image/gif`, 2× `.css` → `text/css`; todos `200` | **PASSOU** |
| Um registro criado pela API é confirmado direto no banco | `POST /api/post` + `docker compose exec -T db psql` | `1 \| SENTINELA-COMPOSE-4.11` | **PASSOU** |
| O registro sobrevive a parar e subir o ambiente | `docker compose down` + `up -d` (sem `-v`) | sentinela presente após containers **removidos e recriados** | **PASSOU** |
| O contador de reinícios do container é zero após 30 segundos | `docker inspect --format '{{.RestartCount}}'` | `app=0`, `db=0`, ambos `healthy` | **PASSOU** |
| A parada do ambiente retorna em menos de 10 segundos | `time docker compose stop` | **0,55 s** | **PASSOU** |

**7 de 7.**

---

## 13.3 — PRD 001 / Milestone 2: Imagem multiplataforma publicada

| Critério | Comando | Saída | Veredito |
|---|---|---|---|
| O manifesto publicado atende às duas arquiteturas sob a mesma referência | `docker buildx imagetools inspect fabricioveronez/kube-news:v1.0.0` | índice OCI com `linux/amd64` **e** `linux/arm64` | **PASSOU** |
| Consumir a imagem não exige credencial | token anônimo em `auth.docker.io` + `GET /manifests/v1.0.0` | `HTTP 200` | **PASSOU** |
| O processo dentro do container não roda como administrador | `docker run … id` nas duas variantes | `uid=1000(node) gid=1000(node)` | **PASSOU** |
| Nenhum segredo, histórico de versionamento ou dependência local está presente na imagem | inspeção do conteúdo de `/app` | ausentes `.git`, `.env`, `docs`, `openspec`, `terraform`, `k8s`, `CLAUDE.md`; busca por `.env*`/`*.pem`/`*credential*` vazia | **PASSOU** |
| A identificação de versão publicada não reaproveita nenhuma anterior | listagem de tags do repositório antes da publicação | só existia `v1`; `v1.0.0` era inédita e não sobrescreveu nada | **PASSOU** |

**5 de 5.**

---

## 13.4 — PRD 003 / Milestone 1: Manifesto definido e provado em cluster local

| Critério | Comando | Saída | Veredito |
|---|---|---|---|
| Um comando sobe o cluster local a partir da configuração versionada | `kind create cluster --name kube-news --config kind/kind-config.yaml` | 2 nós `Ready` | **PASSOU** |
| A versão de Kubernetes do cluster local é a mesma da versão de destino na nuvem | `kubectl version` vs. `cluster_version` no tfvars | `Server v1.36.1` vs. `1.36` | **PASSOU** |
| Um comando aplica todo o deploy, criando os objetos na ordem correta | `sed … \| kubectl apply -f -` | 7 objetos: namespace → configmap → secret → deployment/postgres → service/postgres → deployment/kube-news → service/kube-news | **PASSOU** |
| O contador de reinícios é zero cinco minutos após o deploy | `kubectl get pods -o custom-columns`, 6m27s após deploy limpo | `RESTARTS 0` nos 3 pods | **PASSOU** |
| Nenhum componente está na classe de serviço de menor prioridade | mesma consulta, coluna `QOS` | 3× `Burstable`, nenhum `BestEffort` | **PASSOU** |
| A lista de destinos de cada exposição é não-vazia | `kubectl get endpointslice -n kube-news` | `kube-news` → 2 IPs ready; `postgres` → 1 IP ready | **PASSOU** |
| Um registro criado pela API é confirmado consultando o banco diretamente | `POST /api/post` + `kubectl exec … psql` | `1 \| SENTINELA-KIND-8.6` | **PASSOU** |
| A aplicação responde pelo navegador através da exposição externa | `kubectl get svc kube-news -n kube-news` | `EXTERNAL-IP: <pending>` | **NÃO VERIFICADO** — razão: **decisão do responsável de dispensar `cloud-provider-kind` e validar localmente por port-forward**. A aplicação responde por `kubectl port-forward` (`/`, `/health`, `/ready`, estáticos e `POST /api/post`, todos verificados), o que prova aplicação, Service e seletor — mas **não** a atribuição de `EXTERNAL-IP`. Fecha no EKS |
| O manifesto aplicado é idêntico ao versionado, exceto pela injeção da senha | `diff` entre os dois | única divergência: linha 60, `"<DB_PASSWORD>"` → `"Pg#123"` | **PASSOU** |
| O arquivo versionado contém apenas o marcador de senha | `grep -n 'password:'` + `grep -c 'Pg#123'` | `password: "<DB_PASSWORD>"`; `0` ocorrências do valor real | **PASSOU** — após corrigir o achado A-6 |
| As duas verificações de saúde apontam para destinos diferentes, e a que reinicia não consulta o banco | inspeção do manifesto + teste ativo removendo o pod do banco | liveness `/health`, readiness `/ready`; com o banco fora por 75s os pods da aplicação mantiveram `RESTARTS 0` e `creationTimestamp` inalterado | **PASSOU** |
| Os dados de teste foram removidos ao final | `psql` contagem antes/depois | `1` → `DELETE 1` → `0` | **PASSOU** |

**11 de 12 verificados. 1 NÃO VERIFICADO** (exposição externa — validada por port-forward, que não cobre `EXTERNAL-IP`).

---

## 13.5 / 13.6 — PRD 002 / Milestone 1: Ambiente reproduzível a partir do código

### Verificáveis estaticamente — verificados

| Critério | Comando | Saída | Veredito |
|---|---|---|---|
| Nenhum bloco reutilizável referencia origem externa ao repositório | `grep -rE 'source\s*=' terraform/` | só `../../modules/network`, `../../modules/eks` e `hashicorp/aws` | **PASSOU** |
| Nenhuma definição de ambiente contém recurso solto | `grep -rE '^\s*resource\s' terraform/environments/` | vazio | **PASSOU** |
| O estado e os arquivos locais gerados não estão no controle de versão; o arquivo de versões resolvidas está | `git check-ignore` + `git add -An terraform/` | `.terraform/`, `tfplan`, `*.tfstate`, `*.tfvars` ignorados; `.terraform.lock.hcl` e `.tfvars.example` rastreáveis | **PASSOU** — após corrigir o achado A-9 |
| Formatação e validação passam sem apontamentos | `terraform fmt -recursive -check` + `terraform validate` ×3 | sem apontamentos; `Success! The configuration is valid.` nos dois módulos e no ambiente | **PASSOU** |

### Dependem de infraestrutura em execução — NÃO VERIFICADOS

Razão comum a todos: **infraestrutura não provisionada por decisão de custo.** `terraform apply` e `terraform destroy` não foram executados.

| Critério | O que o plano mostra | Veredito |
|---|---|---|
| A criação a partir de clone limpo entrega dois nodes em estado pronto, sem passo manual no console | `scaling_config: desired_size = 2, min = 2, max = 3` | **NÃO VERIFICADO** |
| Nenhum node possui endereço alcançável a partir da internet | as 4 subnets estão no plano, as privadas com `map_public_ip_on_launch = false`; **porém** `subnet_ids` do node group é *known after apply*, então o plano **não prova** onde os nós caem — só o código mostra a ligação | **NÃO VERIFICADO** |
| As áreas públicas de rede carregam a marcação de descoberta de serviço externo | `kubernetes.io/role/elb = "1"` nas duas públicas e `internal-elb = "1"` nas duas privadas, presentes no plano — mas a **eficácia** (balanceador recebendo endereço) só se prova provisionando | **NÃO VERIFICADO** |
| A versão do Kubernetes está dentro do suporte padrão do provedor | `version = "1.36"` no plano, dentro do suporte padrão em 2026-07-26 | **NÃO VERIFICADO** (a versão *provisionada* não existe) |

**4 verificados, 4 NÃO VERIFICADOS.**

---

## 13.7 — PRD 002 / Milestone 2: Ciclo de vida completo com custo controlado

Os **3 itens** são **NÃO VERIFICADOS**. Razão: `terraform destroy` não foi executado.

| Critério | Situação | Veredito |
|---|---|---|
| O procedimento de remoção está documentado com seus pré-requisitos explícitos | **documentado** no runbook e na [ADR 004](../../../../docs/adr/004-provisionamento-nao-aplica-manifestos.md), incluindo o pré-requisito de remover o Service antes do `destroy` | **NÃO VERIFICADO** — documentado, nunca exercitado |
| Após a remoção, nenhum componente cobrado permanece ativo | nada foi criado, logo nada foi removido | **NÃO VERIFICADO** |
| O pré-requisito de remover primeiro o que o cluster criou por conta própria está registrado e foi exercitado ao menos uma vez | registrado; **não exercitado** — é a metade que falta do critério | **NÃO VERIFICADO** |

---

## 13.8 — Métricas de sucesso

### Medidas nesta execução

| Métrica | PRD | Baseline anterior | Medido | Meta | Situação |
|---|---|---|---|---|---|
| Tempo até a aplicação responder localmente, a partir de clone limpo | 001 | A levantar | **~15 s de build + ~12 s de subida** ≈ 30 s | < 5 min | **atingida** |
| Passos manuais de configuração antes da primeira subida | 001 | A levantar | **0** — nenhum `.env`, nenhum arquivo a preencher | 0 | **atingida** |
| Custo para exercitar uma correção no manifesto | 003 | custo de cluster de nuvem ligado | **0** — cluster `kind` local | 0 | **atingida** |
| Tempo entre alterar o manifesto e ter o resultado observável | 003 | A levantar | **~40 s** (reapply + dois `rollout status`) | < 3 min | **atingida** |

### Continuam sem baseline — **A levantar**

| Métrica | PRD | Por quê |
|---|---|---|
| Passos manuais no console necessários para ter o ambiente de pé | 002 | depende de provisionamento; não executado |
| Componentes cobrados remanescentes após a remoção | 002 | depende de provisionamento e remoção; não executados |
| Tempo entre iniciar a criação e ter o cluster utilizável | 002 | depende de provisionamento; não executado |

**As três métricas do PRD 002 continuam sem medição.**

---

## 13.9 — Problemas encontrados fora do escopo desta mudança

Todos **NÃO CORRIGIDOS**. Estão aqui para não se perderem.

| # | Problema | Onde | Por que não foi corrigido |
|---|---|---|---|
| P-1 | **Rejeição não tratada em tempo de requisição derruba o processo.** `GET /` com a tabela ausente executa `Post.findAll()`, que falha; a rota é `async` e não tem `catch`, e a rejeição termina o processo. Mesma classe do defeito de boot, mas nenhum contorno de ordenação de start a cobre | `src/server.js:74-78` (e as demais rotas `async`) | `src/` está fora do escopo por decisão registrada em Non-Goals |
| P-2 | **A tag `v1` publicada é `amd64` apenas.** Qualquer manifesto ou material que ainda aponte para ela continua sujeito ao `exec format error` em nó `arm64` | Docker Hub, `fabricioveronez/kube-news:v1` | tag publicada não é reescrita — é o requisito de referência imutável. O manifesto entregue aponta para `v1.0.0` |
| P-3 | **Volumes de sessão anterior na máquina** — `kube-news_pgdata` e `kube-news_postgres-data`, inicializados por Postgres anterior à 18 | máquina local | remover dado sem confirmação explícita é proibido pelo requisito de tratamento de conflitos. Se forem descartáveis: `docker volume rm kube-news_pgdata kube-news_postgres-data` |
| P-4 | **O defeito de encerramento no boot continua sendo contornado por ambiente, não corrigido.** O contorno se repete hoje em dois ambientes, e vai se repetir em cada ambiente novo | `src/models/post.js:58-60` | classificado pelo responsável como bug conhecido e aceito |

---

## 13.10 — As duas lacunas continuam declaradas

Nenhuma das duas foi silenciosamente dada como coberta:

1. **O manifesto não foi validado em cluster de nuvem.** Foi provado em `kind` local, na mesma versão menor de Kubernetes, com a aplicação alcançada por `kubectl port-forward`. Ficam sem cobertura: **a atribuição de `EXTERNAL-IP` ao Service do tipo `LoadBalancer`** (dispensada localmente por decisão), o balanceador real e a eficácia da marcação de descoberta, a arquitetura `amd64` dos nós, e a janela de aproximadamente 170 segundos até a primeira resposta.
2. **A infraestrutura não foi provisionada nem destruída.** O código foi escrito, formatado, validado e planejado. Ficam sem cobertura: cota, permissão, disponibilidade de tipo de instância por zona, e todo comportamento de tempo de execução. Um plano válido pode falhar no `apply` por qualquer um deles.

A saída para ambas é uma mudança futura de **provisionamento e deploy em nuvem**, executada quando houver decisão de gastar. Ela consome o manifesto e o código Terraform que esta entrega produz — ambos revisados e provados no que era possível provar sem custo.

---

## 13.11 — Conclusão sobre o PRD 002

**O PRD 002 não pode ser marcado como concluído nesta rodada.**

A entrega dele é **código revisado e planejado, nunca executado**. Metade dos critérios do Milestone 1 e a totalidade dos do Milestone 2 dependem de infraestrutura em execução e permanecem não verificados. Marcá-lo como concluído seria ler os itens omitidos como aprovados — exatamente o que este relatório existe para impedir.

| PRD | Situação |
|---|---|
| **001** — Containerização multiplataforma | **Concluído** — 12 de 12 critérios verificados |
| **002** — Infraestrutura EKS como código | **NÃO CONCLUÍDO** — 4 de 11 critérios verificados; 7 não verificados |
| **003** — Deploy Kubernetes | **Concluído com ressalva** — 11 de 12 verificados; 1 não verificado (`EXTERNAL-IP`, dispensado por decisão em favor de port-forward) |
