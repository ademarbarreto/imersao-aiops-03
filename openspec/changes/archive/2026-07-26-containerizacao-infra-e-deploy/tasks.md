## 1. Proteção do repositório (antes de qualquer coisa)

- [x] 1.1 Adicionar ao `.gitignore` os padrões de Terraform: `*.tfstate`, `*.tfstate.*`, `.terraform/`, `*.tfvars` com exceção de `*.tfvars.example`, `crash.log` — hoje o arquivo não tem nenhuma linha de Terraform
- [x] 1.2 Garantir que `.terraform.lock.hcl` **não** seja ignorado, porque ele deve ser versionado
- [x] 1.3 Confirmar com `git status` que nenhum arquivo de estado seria rastreado, antes de qualquer `terraform init`

## 2. Contrato da aplicação (investigação, sem escrever artefato)

- [x] 2.1 Confirmar no código a porta de escuta, os endpoints de saúde e o contrato de variáveis com seus valores padrão (`src/server.js`, `src/system-life.js`, `src/models/post.js`)
- [x] 2.2 Confirmar quais caminhos resolvem pelo diretório de trabalho do processo, e derivar daí a raiz do diretório de trabalho da imagem
- [x] 2.3 Escrever o contrato de containerização em texto curto e conferir contra o registrado no `CLAUDE.md` e no runbook, anotando divergências

## 3. Ambiente local em Docker

- [x] 3.1 Criar `.dockerignore` cobrindo o diretório de dependências em qualquer profundidade (`**/node_modules`), controle de versão, arquivos de ambiente, artefatos Docker e arquivos de editor
- [x] 3.2 Criar `Dockerfile` com dois estágios (dependências e execução), instalação determinística a partir do arquivo de trava, base `node:24-alpine`
- [x] 3.3 Definir o diretório de trabalho como a raiz do conteúdo de `src/`, com o comando de início em forma de lista
- [x] 3.4 Adicionar iniciador como processo principal para encaminhar o sinal de término, e usuário sem privilégio administrativo
- [x] 3.5 Adicionar verificação de saúde apontando para `/health`, usando capacidade nativa do runtime, sem instalar ferramenta extra
- [x] 3.6 Criar `docker-compose.yml` com aplicação e banco `postgres:18-alpine`, espelhando os valores padrão do código e alterando apenas o endereço do banco
- [x] 3.7 Configurar a verificação de prontidão do banco com o banco e o usuário da aplicação, e amarrar o início da aplicação a essa condição
- [x] 3.8 Declarar volume nomeado para o banco, rede dedicada, nome de projeto, e publicar a porta do banco apenas em `127.0.0.1`
- [x] 3.9 Verificar que valores com caractere especial (`#` na senha padrão) estão escapados corretamente

## 4. Testes do ambiente local com Docker Compose

- [x] 4.1 `docker compose config` — validar a sintaxe e inspecionar a interpolação resultante, conferindo especialmente o escape do `#` na senha padrão
- [x] 4.2 `docker compose build` e `docker image ls` — registrar o tamanho da imagem e comparar com a faixa esperada de Node alpine (150–300 MB); se estourar, investigar dependências de desenvolvimento e furo no `.dockerignore`
- [x] 4.3 `docker compose up -d` a partir de um clone limpo, **sem criar nenhum arquivo `.env`** — se exigir, o requisito de zero-config falhou
- [x] 4.4 `docker compose ps` — confirmar o banco em `healthy` e a aplicação iniciada só depois disso
- [x] 4.5 `docker compose logs app` — confirmar ausência de `ECONNREFUSED` no start, provando que a ordenação por prontidão funcionou
- [x] 4.6 `docker compose exec app id` — confirmar usuário sem privilégio administrativo
- [x] 4.7 `docker inspect --format '{{.RestartCount}}'` no container da aplicação, 30 segundos após a subida — confirmar zero
- [x] 4.8 `curl -i http://localhost:8080/` **a partir do host** — confirmar `HTTP 200` e conteúdo renderizado, não apenas status
- [x] 4.9 Extrair da página inicial cada recurso estático referenciado e requisitar um a um, conferindo status **e** `Content-Type` coerente com a extensão — `text/html` num `.css` é 404 disfarçado
- [x] 4.10 `curl -i http://localhost:8080/health` e `/ready` — confirmar que ambos respondem
- [x] 4.11 `POST /api/post` com um registro sentinela, ler de volta pela API, e confirmar direto no banco com `docker compose exec -T db psql`
- [x] 4.12 `docker compose down` seguido de `docker compose up -d` (**sem `-v`**) — confirmar que o sentinela sobreviveu; `restart` não prova persistência, porque mantém o mesmo sistema de arquivos
- [x] 4.13 Cronometrar `docker compose stop` — retorno em menos de 10 segundos; exatamente 10s indica que o sinal de término não chegou ao processo
- [x] 4.14 Remover o registro sentinela e confirmar com contagem antes e depois

## 5. Imagem multiplataforma publicada

- [x] 5.1 Criar o construtor dedicado que atende múltiplas arquiteturas
- [x] 5.2 Construir `linux/amd64` e `linux/arm64` de forma independente, sem reaproveitar resultado entre arquiteturas
- [x] 5.3 Autenticar no registro e publicar em `fabricioveronez/kube-news` com identificação `v1.0.0`
- [x] 5.4 Inspecionar o manifesto publicado e confirmar que lista as duas arquiteturas sob a mesma referência
- [x] 5.5 Confirmar que a obtenção da imagem funciona sem credencial
- [x] 5.6 Inspecionar o conteúdo da imagem e confirmar ausência de segredos, histórico de controle de versão e dependências do host
- [x] 5.7 Registrar a identificação de versão publicada e o digest correspondente

## 6. Manifesto Kubernetes

- [x] 6.1 Criar `k8s/kube-news.yaml` com os objetos na ordem de dependência: espaço isolado, configuração, segredo, banco, aplicação
- [x] 6.2 Declarar espaço isolado explícito e o conjunto padronizado de identificadores em todos os objetos
- [x] 6.3 Limitar o seletor da carga de trabalho a nome e instância, deixando o identificador de versão fora dele
- [x] 6.4 Declarar reserva e teto de memória e processamento em todo container, incluindo o de inicialização, com reserva de memória igual ao teto
- [x] 6.5 Declarar verificação de inicialização e a que reinicia apontando para `/health`, e a que controla tráfego apontando para `/ready`, com limiares proporcionais à consequência
- [x] 6.6 Adicionar container de inicialização que aguarda o banco aceitar conexões, obtendo endereço e porta do objeto de configuração
- [x] 6.7 Mover toda variável para objeto de configuração ou segredo, sem nenhum valor literal na carga de trabalho
- [x] 6.8 Usar marcador no lugar do valor da senha, com o valor injetado no momento da aplicação
- [x] 6.9 Adicionar o mecanismo de propagação de mudança de configuração, com marcadores delimitando o bloco cuja alteração exige recálculo
- [x] 6.10 Referenciar a imagem por `fabricioveronez/kube-news:v1.0.0`, com política de obtenção coerente com identificação fixa
- [x] 6.11 Definir o serviço da aplicação como exposição externa, com destino de porta referenciado por nome e seletor casando com os identificadores do modelo de pod
- [x] 6.12 Definir o banco com estratégia que derruba a instância antiga antes de subir a nova, sem armazenamento persistente
- [x] 6.13 Alinhar a imagem do container de inicialização com a versão de banco adotada (`postgres:18-alpine`)
- [x] 6.14 Conferir o manifesto contra as seis regras da skill `manifestos-kubernetes`

## 7. Criação do cluster Kubernetes local com kind

- [x] 7.1 Criar `kind/kind-config.yaml` versionado, fixando a imagem de nó `kindest/node:v1.36.x` — a mesma versão menor do EKS de destino
- [x] 7.2 `kind create cluster --name kube-news --config kind/kind-config.yaml`
- [x] 7.3 `kind get clusters` e `kubectl config current-context` — confirmar que o contexto ativo é o do cluster local, e não outro cluster
- [x] 7.4 `kubectl get nodes` — confirmar nós em `Ready`
- [x] 7.5 `kubectl version` — confirmar que a versão do servidor coincide com a fixada para o EKS no grupo 9
- [x] 7.6 Instalar e executar `cloud-provider-kind` para que o Service do tipo externo receba endereço; **não** alterar o tipo do Service no manifesto para contornar a limitação
      **DISPENSADO POR DECISÃO DO RESPONSÁVEL (2026-07-26).** Instalado (`/opt/homebrew/bin/cloud-provider-kind`), mas exige privilégio administrativo (`Error: please run this again with 'sudo'`). Decidido validar localmente por `kubectl port-forward` em vez de atribuir `EXTERNAL-IP`. O manifesto **continua inalterado** — segue `type: LoadBalancer`, e a exposição externa será exercitada no EKS.
- [x] 7.7 `export DB_PASSWORD='Pg#123'` e aplicar com `sed "s|<DB_PASSWORD>|${DB_PASSWORD}|" k8s/kube-news.yaml | kubectl apply -f -`
- [x] 7.8 Confirmar na saída do apply os objetos criados e a ordem em que foram aplicados
- [x] 7.9 `kubectl rollout status` para o banco e para a aplicação, com timeout — ambos devem terminar em `successfully rolled out`
- [x] 7.10 Comparar o conteúdo aplicado com `k8s/kube-news.yaml` e confirmar que a única diferença é o valor de credencial substituindo o marcador

## 8. Verificação ativa do deploy no cluster kind

Nenhuma das falhas desta camada gera erro. `Running` não é prova de nada — cada item abaixo pega uma falha que os outros não pegam.

- [x] 8.1 `kubectl get pods -n kube-news -o custom-columns` com as colunas `READY`, `RESTARTS`, `QOS` — cinco minutos após o deploy
- [x] 8.2 Confirmar `RESTARTS: 0` em todos os pods; valor diferente de zero é achado, e significa que o `initContainer` não segurou o start
- [x] 8.3 Confirmar que nenhum pod está em `BestEffort`; se estiver, faltou `resources` em algum container
- [x] 8.4 `kubectl get endpointslice -n kube-news` — confirmar ao menos um IP por pod pronto em cada Service; lista vazia é seletor desalinhado, e o `apply` retorna sucesso mesmo assim
- [x] 8.5 `kubectl port-forward svc/kube-news 8080:80` e requisitar `/`, `/health` e `/ready` — valida a aplicação sem depender do mecanismo de exposição
- [x] 8.6 `POST /api/post` com um registro sentinela e confirmar `HTTP 200`
- [x] 8.7 `kubectl exec` no pod do banco com `psql` — confirmar o sentinela presente na tabela; é a única verificação que prova o caminho aplicação → Service → banco
- [x] 8.8 `kubectl get svc kube-news -n kube-news` — obter o endereço externo atribuído pelo `cloud-provider-kind` e requisitar a página por ele
      **SUBSTITUÍDO POR PORT-FORWARD, por decisão do responsável.** `EXTERNAL-IP` permanece `<pending>`. Validado por `kubectl port-forward svc/kube-news 18080:80`: `/` `200 text/html`, `/health` `200 application/json`, `/ready` `200`, `<title>Kubenews</title>`, 4 estáticos com `Content-Type` correto, e `POST /api/post` confirmado no banco. Isso prova aplicação, Service e seletor. **Não prova** atribuição de `EXTERNAL-IP` — lacuna que se soma às já declaradas e só fecha no EKS.
- [x] 8.9 Se um teste HTTP der negativo sem erro correspondente em `kubectl logs`, medir de novo por outro caminho antes de investigar — a ferramenta de teste também falha (Problema 6 do runbook)
- [x] 8.10 **Teste da separação de probes:** `kubectl delete pod` do banco e confirmar que os pods da aplicação **não** reiniciam por falha de liveness — o `/health` não toca no banco, então a queda da dependência não pode reiniciar a frota
- [x] 8.11 `kubectl logs <pod> --previous` em qualquer pod que tenha reiniciado — sem `--previous` o log mostra o container vivo, que não é o que falhou
- [x] 8.12 `grep -n 'password:' k8s/kube-news.yaml` — confirmar que o arquivo versionado contém apenas o marcador
- [x] 8.13 Remover o registro sentinela e confirmar com contagem antes e depois
- [x] 8.14 `kind delete cluster --name kube-news` — confirmar que o ciclo criar/validar/remover é rápido o suficiente para servir de laço de correção
      Remoção em **1,97 s** (`Deleted nodes: ["kube-news-control-plane" "kube-news-worker"]`). Ciclo completo medido: criar ~40 s até os nós `Ready`, aplicar + dois `rollout status` ~60 s, remover ~2 s — **menos de 2 minutos**, e a custo zero. Serve como laço de correção do manifesto.

## 9. Infraestrutura EKS como código

- [x] 9.1 Consultar no registro as versões atuais de provedor e de ferramenta, e registrar os valores obtidos com a data
- [x] 9.2 Criar `terraform/modules/network/` com `main.tf`, `variables.tf`, `outputs.tf` e `versions.tf`
- [x] 9.3 Implementar áreas públicas e privadas em duas zonas, com saída controlada única para as privadas
- [x] 9.4 Adicionar as marcações de descoberta: exposição externa nas áreas públicas, exposição interna nas privadas
- [x] 9.5 Criar `terraform/modules/eks/` com a mesma estrutura de quatro arquivos
- [x] 9.6 Implementar cluster na versão `1.36` e grupo de nós gerenciado com dois nós nas áreas privadas
- [x] 9.7 Declarar `required_providers` em cada capacidade, sem nenhum bloco de configuração de provedor dentro delas
- [x] 9.8 Criar `terraform/environments/dev/` com `main.tf`, `variables.tf`, `versions.tf`, `providers.tf` e `terraform.tfvars`
- [x] 9.9 Garantir que a definição do ambiente contenha apenas chamadas de capacidade e leituras, sem nenhuma declaração de recurso solta
- [x] 9.10 Declarar toda variável com tipo e descrição, e expor nas saídas apenas o que o consumidor precisa

## 10. Validação estática da infraestrutura com Terraform (sem custo)

**`terraform apply` e `terraform destroy` estão FORA do escopo desta mudança.** Nenhum recurso é criado na nuvem, e portanto nada é cobrado. A validação aqui é estática: prova que o código é válido, coerente e descreve a infraestrutura pretendida — **não** prova que a nuvem a aceita.

`init` e `plan` fazem apenas leitura: baixam o provedor e consultam a API para resolver `data sources` e checar estado. Nenhum dos dois cria recurso. `plan` exige credencial de leitura configurada; se não houver, pule 10.4–10.5 e registre como não executado, mantendo 10.1–10.3 e 10.6–10.9, que funcionam sem credencial nenhuma.

- [x] 10.1 `terraform fmt -recursive -check` na raiz de `terraform/` — confirmar formatação sem apontamentos
- [x] 10.2 `terraform init -backend=false` em cada módulo e em `terraform/environments/dev/` — resolve provedores e valida referências sem tocar em estado
- [x] 10.3 `terraform validate` em cada módulo e no ambiente — confirmar validação sem erros
- [x] 10.4 `terraform plan -out=tfplan` — gerar o plano; **não** executar `apply` sobre ele
- [x] 10.5 `terraform show tfplan` — revisar recurso a recurso e conferir no plano: nenhum nó com endereço público, marcações de descoberta corretas nas subnets públicas (`kubernetes.io/role/elb`) e privadas (`internal-elb`), versão do cluster `1.36`, dois nós no grupo gerenciado, e contagem total de recursos batendo com o esperado
- [x] 10.6 `grep -rE 'source\s*=' terraform/` — confirmar que toda origem aponta para caminho local, e nenhuma para registro público de terceiros
- [x] 10.7 `grep -rE '^\s*resource\s' terraform/environments/` — confirmar saída vazia, provando que nenhuma definição de ambiente contém recurso solto
- [x] 10.8 `grep -rE 'terraform\.workspace|configuration_aliases|^\s*provider\s' terraform/modules/` — confirmar ausência de referência a workspace e de bloco `provider` dentro dos módulos
- [x] 10.9 `git status --porcelain` e `git check-ignore -v terraform/environments/dev/terraform.tfstate` — confirmar que `*.tfstate` e `.terraform/` **não** são rastreáveis e que `.terraform.lock.hcl` é; se falhar, voltar ao grupo 1 antes de prosseguir
- [x] 10.10 Conferir o código contra as quatro regras da skill `terraform-boas-praticas`, item a item da lista "Antes de entregar"
- [x] 10.11 Registrar explicitamente, no relatório de evidências, que `apply` e `destroy` **não foram executados** e que os critérios de aceite do PRD 002 que dependem de infraestrutura em execução permanecem **não verificados**

## 11. Correção da documentação existente

- [x] 11.1 Atualizar `docs/runbook-deploy-kubernetes.md`: o Problema 1 passa de "prevenir com disciplina" para "resolvido por construção" pela imagem multiplataforma
- [x] 11.2 Substituir no runbook o procedimento de construção por arquitetura pelo procedimento multiplataforma, incluindo a seção de publicação de versão nova
- [x] 11.3 Alinhar no runbook a imagem do container de inicialização com a versão de banco adotada
- [x] 11.4 Atualizar o `CLAUDE.md`: remover a afirmação de que a flag de plataforma é obrigatória no build
- [x] 11.5 Corrigir no `CLAUDE.md` a seção "Estado do working tree", que afirma que `Dockerfile`, `k8s/` e `terraform/` existem em `HEAD` — o último commit os removeu
- [x] 11.6 Registrar no `CLAUDE.md` o cluster local como ambiente de validação do manifesto

## 12. Registro de decisões arquiteturais

- [x] 12.1 Registrar como ADR a decisão de imagem multiplataforma com construção independente por arquitetura
- [x] 12.2 Registrar como ADR a separação entre o caminho de construção local e o de publicação
- [x] 12.3 Registrar como ADR o estado de provisionamento local em vez de remoto, com o risco assumido
- [x] 12.4 Registrar como ADR a separação entre provisionamento de infraestrutura e aplicação de manifestos
- [x] 12.5 Registrar como ADR o banco no cluster sem armazenamento persistente
- [x] 12.6 Registrar como ADR a validação em cluster local sem adaptação do manifesto

## 13. Fechamento dos critérios de aceite dos PRDs

Portão final. Cada item marca um checklist de milestone dos PRDs em `docs/prds/`, usando as evidências produzidas nos grupos 4, 8 e 10. **Evidência, não adjetivo** — `RESTARTS: 0` prova; "está estável" não.

- [x] 13.1 Montar a tabela de evidências, uma linha por critério, com o comando executado e a saída obtida; dimensão não aplicável entra como `n/a` **com a razão**, e dimensão não verificada entra como não executada — item omitido é lido como item aprovado
- [x] 13.2 PRD 001 / Milestone 1 — marcar os 7 itens de "Ambiente local reproduzível" com as evidências do grupo 4
- [x] 13.3 PRD 001 / Milestone 2 — marcar os 5 itens de "Imagem multiplataforma publicada" com as evidências do grupo 5
- [x] 13.4 PRD 003 / Milestone 1 — marcar os 12 itens de "Manifesto definido e provado em cluster local" com as evidências dos grupos 7 e 8
- [x] 13.5 PRD 002 / Milestone 1 — marcar **apenas** os itens verificáveis estaticamente: nenhum módulo de terceiros, nenhum recurso solto na definição de ambiente, estado fora do controle de versão com o arquivo de travas versionado, formatação e validação sem apontamentos
- [x] 13.6 PRD 002 / Milestone 1 — registrar como **NÃO VERIFICADO, com a razão "infraestrutura não provisionada por decisão de custo"**, os itens que exigem cluster em execução: dois nós em `Ready`, ausência de endereço público nos nós, marcações de descoberta efetivas nas subnets, e versão do cluster provisionada
- [x] 13.7 PRD 002 / Milestone 2 — registrar os 3 itens de "Ciclo de vida completo com custo controlado" como **NÃO VERIFICADOS**; o procedimento de remoção pode ser documentado, mas não foi exercitado
- [x] 13.8 Registrar as métricas de sucesso que puderam ser medidas nesta execução, e marcar explicitamente como "A levantar" as que continuam sem baseline — as três métricas do PRD 002 dependem de provisionamento e continuam sem medição
- [x] 13.9 Listar os problemas encontrados fora do escopo desta mudança, marcados explicitamente como **não corrigidos**
- [x] 13.10 Confirmar que as duas lacunas continuam declaradas e não foram silenciosamente dadas como cobertas: o manifesto não foi validado em cluster de nuvem, e a infraestrutura não foi provisionada nem destruída
- [x] 13.11 Concluir explicitamente que o **PRD 002 não pode ser marcado como concluído** nesta rodada — a entrega dele é código revisado e planejado, nunca executado
