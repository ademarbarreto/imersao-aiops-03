## Why

O `kube-news` só roda hoje em uma máquina que já tenha Node e PostgreSQL instalados, o cluster que o executa não nasce de código versionado, e o deploy depende de conhecimento tácito de quem já sofreu os oito problemas registrados em `docs/runbook-deploy-kubernetes.md`. Duas dessas lacunas já custaram tempo real neste projeto: uma imagem construída na arquitetura errada atravessou build, push e apply sem reclamar e só falhou dentro do cluster (`exec format error`), e a aplicação entrou em `CrashLoopBackOff` porque termina quando o banco não responde no boot.

O material é seguido por terceiros. Cada lacuna dessas vira, na prática, uma dependência de o instrutor estar por perto.

## What Changes

- **Ambiente local em um comando** — aplicação e banco sobem juntos a partir de um clone limpo, sem instalar nada e sem criar arquivo de configuração. A ordem de subida é amarrada à prontidão real do banco, contornando o defeito conhecido de inicialização.
- **Imagem multiplataforma publicada** — uma referência de versão atende `linux/amd64` e `linux/arm64`, cada arquitetura construída independentemente, publicada em `fabricioveronez/kube-news` (público). Isso **elimina por construção** a classe de falha de arquitetura, em vez de preveni-la por disciplina.
- **BREAKING (procedimento)** — o runbook e o `CLAUDE.md` afirmam hoje que `--platform linux/amd64` "não é opcional" e prescrevem inspecionar a arquitetura antes de todo push. Com a imagem multiplataforma isso deixa de valer, e os dois documentos passam a ensinar um procedimento obsoleto se não forem corrigidos nesta mudança.
- **Infraestrutura EKS como código, escrita e validada estaticamente** — rede com áreas públicas e privadas em duas zonas, nodes em rede privada, cluster e node group. Inclui as marcações de descoberta de rede sem as quais a exposição da aplicação fica pendente para sempre, sem erro em lugar nenhum. **`terraform apply` e `destroy` estão fora do escopo:** nenhum recurso é criado na nuvem, e a validação é `fmt`, `validate`, `plan` e revisão do plano — tudo a custo zero.
- **Remoção do ambiente documentada como procedimento de primeira classe** — com o pré-requisito explícito de remover antes o balanceador criado pelo cluster, que não está no estado do provisionamento e trava a remoção da rede. Documentada, não exercitada.
- **Manifesto Kubernetes versionado** — conjunto completo aplicável de uma vez, com recursos declarados em todo container, verificações de saúde com propósitos distintos, configuração fora do workload, credencial como marcador, e ordenação do start por componente de inicialização.
- **Validação em cluster local** — o manifesto é provado num cluster `kind` na própria máquina, na mesma versão de Kubernetes de destino, sem conta em nuvem e sem custo. O manifesto validado é idêntico ao entregue — nada é trocado para o teste passar.

## Capabilities

### New Capabilities

- `ambiente-local-docker`: subida da aplicação e do banco em um comando, zero-config, com ordem de inicialização amarrada à prontidão do banco e persistência entre ciclos
- `imagem-multiplataforma`: construção e publicação da imagem para múltiplas arquiteturas sob uma referência de versão imutável, em registro público
- `infraestrutura-eks`: provisionamento e remoção do cluster e da rede a partir de código versionado, com estado local e separação entre definição de capacidade e valores de ambiente
- `manifesto-deploy-kubernetes`: definição versionada dos objetos de deploy da aplicação, com recursos, verificações de saúde, configuração externa e credencial fora do repositório
- `validacao-cluster-local`: cluster Kubernetes local para exercitar o manifesto, e o conjunto de verificações ativas que provam o deploy contra as falhas silenciosas conhecidas

### Modified Capabilities

Nenhuma. `openspec/specs/` está vazio — esta é a primeira mudança do projeto.

## Impact

**Artefatos criados**

- `Dockerfile`, `.dockerignore`, `docker-compose.yml` — raiz do repositório
- `terraform/modules/{network,eks}/` e `terraform/environments/dev/`
- `k8s/kube-news.yaml` — arquivo único, ordem dos documentos significativa
- Configuração do cluster local `kind`, versionada

**Artefatos modificados**

- `.gitignore` — hoje **sem nenhuma linha de Terraform**. Com estado local e repositório público, um `git add .` após o primeiro `terraform init` publica o `terraform.tfstate`, que carrega dados sensíveis do cluster em texto claro. É o único risco desta mudança que causa dano antes de qualquer código ser escrito.
- `docs/runbook-deploy-kubernetes.md` — o Problema 1 passa de "prevenir com disciplina" para "resolvido por construção"; a imagem do componente de inicialização precisa alinhar com a versão de banco adotada
- `CLAUDE.md` — mesma correção sobre a flag de plataforma; e a seção "Estado do working tree" está desatualizada (afirma que `Dockerfile`, `k8s/` e `terraform/` existem em `HEAD`, mas o último commit os removeu)

**Sem alteração**

- `src/` — o código da aplicação não é tocado. O defeito de inicialização foi classificado como bug conhecido e é contornado em cada ambiente, não corrigido.

**Dependências externas**

- Conta Docker Hub com permissão de publicação; `kind` instalado na máquina de quem valida. Credencial AWS **de leitura** é opcional: sem ela, `terraform plan` é pulado e registrado como não executado, mas `fmt`, `init -backend=false` e `validate` continuam funcionando.

**Custo**

- **Zero.** Nenhum recurso de nuvem é criado nesta mudança. Control plane, NAT Gateway e balanceador cobrariam por hora enquanto ligados — é justamente por isso que `apply` fica fora. Os únicos efeitos externos são a publicação da imagem no registro público (aditiva) e o cluster local, que roda como containers na máquina.

**Rastreabilidade**

- `docs/prds/001-containerizacao-multiplataforma.md` → `ambiente-local-docker`, `imagem-multiplataforma`
- `docs/prds/002-infraestrutura-eks-como-codigo.md` → `infraestrutura-eks` — **entrega parcial:** o código é escrito e validado estaticamente, mas nenhum critério de aceite que exija cluster em execução pode ser fechado. O PRD 002 não é concluído por esta mudança.
- `docs/prds/003-deploy-kubernetes.md` → `manifesto-deploy-kubernetes`, `validacao-cluster-local`

**Lacuna declarada**

Nada é validado na nuvem nesta rodada — nem a infraestrutura, nem o manifesto. Ficam sem cobertura: o provisionamento funcionar de fato (cota, permissão, disponibilidade por zona), o balanceador real e a eficácia da marcação de descoberta, a arquitetura `amd64` dos nodes, a janela de ~170s até a primeira resposta, e o ciclo de remoção. A saída é uma mudança futura de provisionamento e deploy em nuvem, executada quando houver decisão de gastar.
