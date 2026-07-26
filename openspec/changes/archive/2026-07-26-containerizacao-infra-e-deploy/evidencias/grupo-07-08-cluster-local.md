# Grupos 7 e 8 — Deploy e verificação ativa no cluster kind (executado em 2026-07-26)

Cluster: `kind` v0.32.0, imagem de nó `kindest/node:v1.36.1`, 1 control-plane + 1 worker, arquitetura **arm64**.

## Grupo 7 — Criação e aplicação

| # | Comando | Saída obtida | Veredito |
|---|---|---|---|
| 7.1 | `kind/kind-config.yaml` versionado | imagem de nó fixada em `kindest/node:v1.36.1` | PASSOU |
| 7.2 | `kind create cluster --name kube-news --config kind/kind-config.yaml` | cluster criado, contexto definido | PASSOU |
| 7.3 | `kind get clusters` / `kubectl config current-context` | `kube-news` / `kind-kube-news` | PASSOU — ver achado A-5 |
| 7.4 | `kubectl get nodes` | `kube-news-control-plane Ready`, `kube-news-worker Ready`, ambos `v1.36.1` | PASSOU |
| 7.5 | `kubectl version` | `Client v1.36.1`, `Server v1.36.1` | PASSOU — mesma versão menor do EKS de destino (`cluster_version = "1.36"`) |
| 7.6 | `cloud-provider-kind` | **dispensado por decisão** — ver B-1 | SUBSTITUÍDO por port-forward |
| 7.7 | `sed "s\|<DB_PASSWORD>\|${DB_PASSWORD}\|" k8s/kube-news.yaml \| kubectl apply -f -` | 7 objetos criados | PASSOU |
| 7.8 | Saída do apply | `namespace` → `configmap` → `secret` → `deployment/postgres` → `service/postgres` → `deployment/kube-news` → `service/kube-news` | PASSOU — ordem de dependência respeitada |
| 7.9 | `kubectl rollout status ... --timeout=300s` | `deployment "postgres" successfully rolled out`; `deployment "kube-news" successfully rolled out` | PASSOU |
| 7.10 | `diff` entre o versionado e o aplicado | linha 60, única divergência: `password: "<DB_PASSWORD>"` → `password: "Pg#123"` | PASSOU |

### Propagação de configuração, exercitada de verdade

Ao corrigir o comentário do Secret (achado A-6), o hash do bloco de config mudou de `807a850e…` para `2004f906…`. O reapply produziu `deployment.apps/postgres configured` e `deployment.apps/kube-news configured`, e ambos rolaram — enquanto `configmap` e `service` ficaram `unchanged`. O mecanismo de propagação funciona: mudou a config, mudou o template, o rollout acontece sozinho.

## Grupo 8 — Verificação ativa

Leitura tomada **6m27s** após um deploy limpo (namespace recriado do zero às 15:11:36Z, leitura às 15:18:03Z).

| # | Comando | Saída obtida | Veredito |
|---|---|---|---|
| 8.1 | `kubectl get pods -n kube-news -o custom-columns` | 3 pods `Running`, `READY true`, `RESTARTS 0`, `QOS Burstable` | PASSOU |
| 8.2 | `RESTARTS: 0` em todos | `0`, `0`, `0` | PASSOU — o `initContainer` segurou o start |
| 8.3 | Nenhum pod em `BestEffort` | todos `Burstable` | PASSOU |
| 8.4 | `kubectl get endpointslice -n kube-news` | `kube-news` → `[10.244.1.13],[10.244.1.11]` ready `true,true`; `postgres` → `[10.244.1.12]` ready `true` | PASSOU — nenhuma lista vazia, seletor alinhado |
| 8.5 | `kubectl port-forward svc/kube-news 18080:80` + `/`, `/health`, `/ready` | `200 text/html`, `200 application/json`, `200`; `<title>Kubenews</title>` | PASSOU |
| 8.6 | `POST /api/post` com sentinela | `HTTP 200` | PASSOU |
| 8.7 | `kubectl exec` no pod do banco + `psql` | `1 \| SENTINELA-KIND-8.6` | PASSOU — prova o caminho aplicação → Service → banco |
| 8.8 | `EXTERNAL-IP` do Service | `<pending>`; validado por port-forward — ver B-1 | SUBSTITUÍDO por port-forward |
| 8.9 | Segunda medição por outro caminho | aplicado de fato — ver achado A-7 | PASSOU |
| 8.10 | `kubectl delete pod` do banco | app com `RESTARTS 0` e `creationTimestamp` inalterado após 75s com o banco fora | PASSOU |
| 8.11 | `kubectl logs --previous` | executado no pod que reiniciou — ver achado A-8 | PASSOU |
| 8.12 | `grep -n 'password:' k8s/kube-news.yaml` | só `password: "<DB_PASSWORD>"`; `grep -c 'Pg#123'` → `0` | PASSOU — após corrigir A-6 |
| 8.13 | Remoção do sentinela | contagem `1` → `DELETE 1` → `0` | PASSOU |
| 8.14 | `time kind delete cluster --name kube-news` | **1,97 s** — `Deleted nodes: ["kube-news-control-plane" "kube-news-worker"]` | PASSOU |

### 8.8 — evidência parcial obtida sem privilégio administrativo

O Service **roteia tráfego fim a fim**, verificado pelo `nodePort` que o próprio Service do tipo externo expõe:

```
node=172.18.0.2  nodePort=32352
GET / -> HTTP 200
<title>Kubenews</title>
```

Isso prova seletor, endpoints e caminho de rede. **Não prova** a atribuição de `EXTERNAL-IP`, que é justamente o que depende do bloqueio B-1.

## Decisão sobre a exposição externa

### B-1 — `cloud-provider-kind` dispensado; validação local por port-forward

`cloud-provider-kind` foi instalado (`/opt/homebrew/bin/cloud-provider-kind`) mas recusa iniciar sem privilégio administrativo: `Error: please run this again with 'sudo'`.

**Decisão do responsável em 2026-07-26:** não usar `cloud-provider-kind`; validar localmente por `kubectl port-forward`. A exposição externa de verdade será exercitada no EKS, onde o balanceador é real.

O manifesto **não foi alterado**: o Service segue `type: LoadBalancer`, e o que é entregue continua sendo exatamente o que foi validado. A decisão troca o *método de verificação local*, não o artefato — que é a distinção que a decisão D7 protege.

### Reexecução em cluster recriado (2026-07-26, 17:10:21Z)

O cluster foi recriado pelo responsável e o deploy reaplicado do zero. Resultados:

| Verificação | Saída | Veredito |
|---|---|---|
| Rollouts | `postgres` e `kube-news` — `successfully rolled out` | PASSOU |
| Pods aos **5m32s** (17:15:53Z) | 3 pods `Running`, `READY true`, `RESTARTS 0`, `QOS Burstable` | PASSOU |
| `EndpointSlice` | `kube-news` → `[10.244.1.3],[10.244.1.4]` ready `true,true`; `postgres` → `[10.244.1.2]` ready `true` | PASSOU |
| Endpoints por port-forward | `/` `200 text/html`, `/health` `200 application/json`, `/ready` `200`; `<title>Kubenews</title>` | PASSOU |
| Estáticos por port-forward | `.svg` `image/svg+xml`, `.gif` `image/gif`, 2× `.css` `text/css` — todos `200` | PASSOU |
| Caminho app → Service → banco | `POST /api/post` `200`; `psql` → `1 \| SENTINELA-PF-8.8`; lido de volta na página | PASSOU |
| Limpeza | contagem `1` → `DELETE 1` → `0` | PASSOU |
| Separação de probes | pod do banco removido; pods da aplicação com `RESTARTS 0` e `creationTimestamp` inalterado (17:10:21Z) enquanto o banco foi recriado às 17:12:25Z | PASSOU |
| `EXTERNAL-IP` | `<pending>` | **NÃO VERIFICADO** — decisão acima |

Nota de método: a leitura de 5 minutos foi tomada **sem** requisitar `/`, porque com a tabela ausente após o teste de probes aquela rota derrubaria um pod pelo defeito P-1 e contaminaria a contagem de reinícios.

### Ciclo criar / validar / remover — medido

| Etapa | Tempo | Comando |
|---|---|---|
| Criar | ~40 s até os dois nós `Ready` | `kind create cluster --name kube-news --config kind/kind-config.yaml` |
| Aplicar e estabilizar | ~60 s | `sed … \| kubectl apply -f -` + dois `kubectl rollout status` |
| Remover | **1,97 s** | `kind delete cluster --name kube-news` |

**Menos de 2 minutos o ciclo inteiro, a custo zero.** É o que torna o cluster local viável como laço de correção do manifesto — a métrica do PRD 003 "tempo entre alterar o manifesto e ter o resultado observável" (meta < 3 min) é atendida com folga.

Depois da remoção, `kubectl config current-context` fica **sem contexto definido** — o `kind` remove a entrada que ele mesmo criou. Um `kubectl` seguinte falha com `current-context is not set`, que é comportamento esperado e não sintoma.

## Achados

### A-5 — O contexto ativo apontava para um cluster EKS inexistente

Antes da criação do cluster local, `kubectl config current-context` era `arn:aws:eks:us-east-1:206765900626:cluster/kube-news-dev`, e qualquer `kubectl` falhava com `no such host` na resolução do endpoint. O `kind create cluster` trocou o contexto. Registrado porque um `kubectl apply` disparado antes dessa troca teria falhado por um motivo que não tem nada a ver com o manifesto.

### A-6 — O arquivo versionado continha a senha real dentro de um comentário

O campo `password` já carregava o marcador, mas o comentário imediatamente acima trazia `"Pg#123"` como exemplo de formatação — o valor real, no repositório público. Substituído por um comentário que ensina a regra (`senha com '#' exige aspas`) sem exibir o valor. Hash do bloco recalculado nas duas annotations. `grep -c 'Pg#123' k8s/kube-news.yaml` agora retorna `0`.

### A-7 — A ferramenta de teste falhou, não a aplicação (Problema 6 do runbook)

Uma bateria de `curl` passou a retornar `HTTP 000` em `/`, `/health` e `/ready` ao mesmo tempo, **sem erro correspondente** em `kubectl logs`. Aplicada a disciplina do item 8.9: segunda medição por outro caminho, de dentro do cluster, antes de investigar.

```
/health  -> HTTP 200      (de dentro do cluster)
```

A aplicação estava íntegra. O processo de `kubectl port-forward` é que havia morrido. Sem a segunda medição, a investigação teria começado pela aplicação — e não haveria nada lá.

### A-8 — Defeito novo: rejeição não tratada em tempo de requisição derruba o processo

**Não está entre os oito problemas do runbook.** Descoberto como consequência encadeada de D6 (banco sem armazenamento persistente).

Sequência observada:

1. O pod do banco foi recriado no teste 8.10 → como não há volume, a tabela `Posts` deixou de existir.
2. Os pods da aplicação **não** reiniciaram por isso — `/health` não toca no banco, e a separação de probes se manteve. É o resultado esperado de 8.10.
3. A primeira requisição a `GET /` depois disso executou `Post.findAll()`, que falhou com `relation "Posts" does not exist`.
4. A rota é `async` e **não tem `catch`** (`src/server.js:74-78`). A rejeição não tratada terminou o processo — `kubectl logs --previous` mostra o erro do Sequelize seguido de `Node.js v24.18.0`.
5. O container reiniciou, o boot rodou `sync({alter:true})`, a tabela foi recriada, e `GET /` voltou a responder `200`.

É a **mesma classe de defeito** do encerramento por dependência ausente no boot, mas em tempo de requisição — e por isso nenhum contorno de ordenação de start a cobre. `initContainer` e `depends_on` resolvem o boot; não resolvem isto.

**Não corrigido**, e deliberadamente: `src/` está fora do escopo desta mudança por decisão registrada em Non-Goals. Entra no relatório como problema encontrado fora do escopo (13.9).
