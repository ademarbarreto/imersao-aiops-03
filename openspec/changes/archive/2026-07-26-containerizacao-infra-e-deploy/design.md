## Context

O `kube-news` é uma aplicação Node/Express de arquivo único, estável e pequena, usada como alvo de uma imersão de AIOps. O trabalho real está nos artefatos de infraestrutura em volta dela. Três fatos do código, verificados em `src/`, restringem tudo o que segue:

| Fato | Local | Consequência |
|---|---|---|
| Porta `8080` fixa no código, sem variável de ambiente | `src/server.js:81` | não adianta parametrizar porta em lugar nenhum |
| Estáticos e modelos de página resolvem pelo diretório de trabalho do processo | `src/server.js:24,27` | o conteúdo de `src/` precisa ser a raiz do diretório de trabalho na imagem |
| `initDatabase()` chama `sync({alter:true})` e **descarta a promise** | `src/server.js:80`, `src/models/post.js:59` | banco fora no boot → rejeição não tratada → processo termina |

O terceiro é o que mais custa. Ele já produziu `CrashLoopBackOff` num deploy real (Problema 2 do runbook), e foi classificado pelo responsável como bug conhecido e aceito — não será corrigido. A consequência é estrutural: **o contorno se repete em cada ambiente**, hoje no ambiente local e no cluster, amanhã em qualquer ambiente novo.

Existe ainda um ativo que esta mudança não pode ignorar: `docs/runbook-deploy-kubernetes.md` documenta oito problemas que **aconteceram de verdade** neste projeto, cada um com sintoma, causa e correção. A maior parte dos requisitos desta mudança é a codificação desses oito.

**Versões verificadas em 2026-07-26** (nenhuma vinda de memória):

| Item | Valor | Origem |
|---|---|---|
| Node.js Active LTS | 24 (22 caiu para manutenção) | nodejs/Release, endoflife.date |
| PostgreSQL estável | 18.4 | postgresql.org/support/versioning |
| Provedor AWS Terraform | 6.56.0 | registry.terraform.io |
| Terraform CLI | 1.15.8 | api.releases.hashicorp.com |
| EKS suporte padrão | 1.36, 1.35, 1.34, 1.33 (1.33 sai em 29/07/2026) | docs.aws.amazon.com |
| kind — imagem de nó padrão | `kindest/node:v1.36.1` | kubernetes-sigs/kind |

A coincidência entre a versão padrão do kind e o topo do suporte do EKS é o que torna a validação local fiel.

## Goals / Non-Goals

**Goals:**

- Subir aplicação e banco localmente em um comando, a partir de clone limpo, sem configuração manual
- Eliminar **por construção** a classe de falha de arquitetura de imagem, em vez de preveni-la por disciplina
- Escrever o código que faz o cluster nascer de forma versionada e reproduzível, incluindo o caminho de remoção
- Produzir um manifesto versionado que incorpore as oito lições do runbook desde o início
- Provar o manifesto num cluster local, sem conta em nuvem e sem custo, na mesma versão de Kubernetes de destino
- **Executar toda a validação desta mudança a custo zero**

**Non-Goals:**

- **Provisionar qualquer infraestrutura na nuvem.** `terraform apply` e `terraform destroy` estão explicitamente fora. A validação do Terraform é estática — ver D10
- Corrigir o código da aplicação, incluindo o defeito de inicialização e a alteração de schema no boot
- Pipeline de CI/CD, varredura e assinatura de imagem
- Desenvolvimento com código editável dentro do container
- Camadas de template sobre o manifesto (Helm, Kustomize), entrada HTTP compartilhada, escalonamento automático, políticas de rede
- Ambientes de infraestrutura além de `dev`; banco gerenciado
- Validação do manifesto no cluster de nuvem — lacuna declarada, ver Open Questions

## Decisions

### D1 — Imagem multiplataforma, cada arquitetura construída por inteiro

**Escolha:** publicar um índice cobrindo `linux/amd64` e `linux/arm64` sob uma referência, construindo cada arquitetura independentemente.

**Por quê:** hoje a arquitetura correta depende de alguém digitar uma flag. Build, publicação e aplicação passam sem reclamar, e a falha só aparece quando o kernel do nó tenta executar o binário — três passos depois da causa.

**Alternativa considerada e descartada:** instalar as dependências uma única vez na arquitetura do construtor e reaproveitar nas duas variantes. É barato hoje, porque nenhuma dependência precisa ser compilada (`pg` e `sequelize` são JavaScript puro). Foi descartada porque, no dia em que alguém adicionar uma dependência com extensão nativa, o resultado passa a conter um binário de uma arquitetura só — e a imagem da outra quebra **em execução no cluster**, não na construção. Mesma assinatura do erro que esta mudança elimina.

### D2 — Ambiente local e publicação são caminhos separados

**Escolha:** o ambiente local constrói nativamente e identifica a imagem como local; a publicação multiplataforma é um caminho próprio que envia direto ao registro.

**Por quê:** o armazenamento local de imagens do mecanismo padrão não guarda índice multiplataforma, e o construtor padrão não atende múltiplas arquiteturas — é preciso um construtor dedicado, e a saída vai para o registro. Tentar unificar os dois caminhos quebraria a promessa de subida em um comando.

**Consequência aceita:** dois caminhos para manter. A identificação local distinta evita que a construção local sobrescreva a imagem publicada no cache da máquina.

### D3 — O provisionamento da infraestrutura não aplica os manifestos

**Escolha:** a ferramenta de infraestrutura cria o cluster; a ferramenta de linha de comando do Kubernetes aplica o manifesto.

**Por quê:** um provedor de Kubernetes configurado a partir de atributos de um cluster que o mesmo estado ainda vai criar não pode ser resolvido no primeiro planejamento — a configuração do provedor precede o conhecimento do endpoint. O sintoma é o clássico "rode duas vezes", e ele reaparece em toda remoção.

**Acoplamento residual:** apenas a marcação de descoberta nas áreas públicas de rede, criada pelo provisionamento e sem a qual a exposição nunca completa.

### D4 — Estado do provisionamento local

**Escolha:** estado na máquina de quem executa, conforme decidido pelo responsável.

**Por quê:** há um operador só, e a alternativa exigiria criar antes um repositório de estado compartilhado — passo extra sem benefício aqui.

**Risco assumido e sua contrapartida obrigatória:** o estado carrega dados sensíveis do cluster em texto claro, e o repositório é público. A exclusão do estado no controle de versão precisa existir **antes** da primeira inicialização — não é higiene, é a única mitigação. Perder o estado também remove a capacidade de destruir pelo código, deixando componentes cobrando.

### D5 — Nós em rede privada, com um único ponto de saída

**Escolha:** nós nas áreas privadas, saída controlada única.

**Por quê:** é a topologia correta; a alternativa mais barata expõe os nós diretamente. Um ponto de saída por zona multiplicaria o custo sem benefício em laboratório.

**Interação não-óbvia entre duas decisões:** com saída única e registro público consumido anonimamente, todo o cluster obtém imagens por um mesmo endereço de origem — e o limite de consumo é contado por origem. O sintoma é falha de obtenção que se parece com erro de referência de imagem.

### D6 — Banco no cluster, sem armazenamento persistente

**Escolha:** manter a decisão de laboratório já registrada no runbook.

**Por quê:** os dados são descartáveis e o contraste é conteúdo didático.

**Consequência que precisa de tratamento explícito:** a estratégia de atualização precisa derrubar a instância antiga antes de subir a nova. Com atualização gradual, existiriam dois bancos com dados divergentes atendendo ao mesmo serviço enquanto o rollout durasse.

**Alternativa considerada e descartada:** banco gerenciado provisionado pela infraestrutura. Eliminaria os Problemas 3 e 4 do runbook de uma vez, e o custo de fazê-lo caiu bastante agora que existe infraestrutura como código. Descartada para manter o conteúdo e o custo baixos.

### D7 — Validação em cluster local, sem adaptar o manifesto

**Escolha:** provar o manifesto em `kind`, na mesma versão menor de Kubernetes do destino, dando ao ambiente local a capacidade de atender exposição externa.

**Por quê:** remove custo e tempo de provisionamento do ciclo de correção, e permite que quem acompanha o material exercite tudo sem conta em nuvem.

**Alternativa considerada e descartada:** trocar o tipo de serviço por um que funcione nativamente no cluster local. Descartada porque produziria um manifesto validado diferente do entregue — a falha reapareceria só na nuvem, que é exatamente o que a validação existe para evitar.

**Ganho não planejado:** os nós do kind são containers na máquina de desenvolvimento, de arquitetura `arm64`. A validação passa a exercitar a variante que o ambiente de nuvem nunca usaria.

### D8 — Contorno do encerramento por dependência, repetido por ambiente

**Escolha:** ordenar o start em cada ambiente — condição de prontidão no ambiente local, container auxiliar de inicialização no cluster.

**Por quê:** consequência direta de não corrigir o código. Verificação de inicialização cobre boot **lento**; não cobre boot que **termina**. Um processo que encerra com código de erro morre antes de existir o que a verificação consultaria — o orquestrador vê um container terminado, não um demorado.

**Alternativa considerada e descartada:** tratamento de erro com nova tentativa no `initDatabase`. Resolveria em todos os ambientes de uma vez e são poucas linhas. Descartada porque o responsável classificou como bug conhecido e aceito.

### D10 — Infraestrutura de nuvem escrita e planejada, nunca provisionada

**Escolha:** o código Terraform é escrito, formatado, validado e planejado, mas `apply` e `destroy` não são executados nesta mudança. Toda a validação roda a custo zero.

**Por quê:** decisão do responsável — os testes desta mudança não devem gerar custo. Control plane, ponto de saída de rede e balanceador cobram por hora enquanto ligados, e a validação do manifesto já acontece localmente (D7), sem depender de nuvem.

**O que a validação estática de fato prova:** que o código é sintaticamente válido, que as referências entre capacidades resolvem, que a estrutura respeita as regras do projeto (nenhum recurso solto no ambiente, nenhuma origem de terceiros, nenhum bloco de provedor dentro de capacidade), e — quando há credencial de leitura — que o plano descreve a infraestrutura pretendida, com a contagem e os atributos esperados.

**O que ela não prova, e é preciso dizer:** que a nuvem aceita a requisição. Cota, permissão, disponibilidade de tipo de instância em zona, e todo comportamento de tempo de execução ficam sem cobertura. Um plano válido pode falhar no `apply` por qualquer um deles.

**Consequência direta e não negociável:** o PRD 002 **não pode ser marcado como concluído** nesta rodada. Os critérios de aceite dele que exigem cluster em execução — dois nós prontos, ausência de endereço público nos nós, marcações de descoberta efetivas, versão provisionada, e o ciclo completo de remoção — permanecem não verificados, e precisam entrar no relatório como **não executados com a razão**, nunca omitidos. Item omitido é lido como item aprovado.

**Efeito colateral sobre o Problema 5 do runbook:** a marcação de descoberta nas subnets é o único acoplamento real entre a camada de infraestrutura e a de deploy. Ela pode ser conferida no plano, mas sua eficácia — o balanceador de fato recebendo endereço — só se prova provisionando. Continua sendo a falha silenciosa mais provável no primeiro `apply` real.

**Alternativa considerada e descartada:** provisionar, validar e destruir na mesma sessão, mantendo o custo em poucos minutos de uso. Descartada porque o pedido foi custo zero, não custo baixo, e porque a destruição depende de um pré-requisito que, se esquecido, deixa componente cobrando indefinidamente — exatamente o risco que a decisão elimina.

### D9 — Versões adotadas

Node `24-alpine`, PostgreSQL `18-alpine`, EKS `1.36`, provedor AWS `~> 6.56`, Terraform `>= 1.15`, imagem de nó do kind na `v1.36.x`.

**Por quê:** todas verificadas na origem em 2026-07-26. A base alpina é segura aqui porque nenhuma dependência tem extensão nativa.

**Risco declarado:** as dependências da aplicação estão travadas em versões de 2022. `sync({alter:true})` gera comandos de esquema no boot — é onde uma incompatibilidade apareceria. Só a construção e a primeira execução provam; o recuo é descer para Node 22, ainda em manutenção.

## Risks / Trade-offs

- **Estado de provisionamento publicado no repositório público** → o `.gitignore` **não tem hoje nenhuma linha de Terraform**. Continua sendo o primeiro passo da implementação: mesmo sem `apply`, um `terraform init` já cria `.terraform/`, e um `plan` com backend local pode gerar arquivo de estado. É o único risco desta mudança que causa dano antes de qualquer recurso existir.
- **Código de infraestrutura entregue sem nunca ter sido executado** (D10) → a validação estática não cobre cota, permissão, disponibilidade de tipo de instância por zona, nem comportamento de tempo de execução. O primeiro `apply` real é onde isso aparece, e ele não acontece nesta mudança. Mitigação: revisão do plano recurso a recurso, conferência contra as regras da skill, e registro explícito dos critérios não verificados.
- **Marcação de descoberta nas subnets conferida no plano, mas não em efeito** → é o Problema 5 do runbook e o único acoplamento real entre infraestrutura e deploy. Continua sendo a falha silenciosa mais provável no primeiro provisionamento real.

**Riscos diferidos** — reais, mas que só se materializam quando o provisionamento for executado, fora desta mudança:

- **Perda do estado deixa infraestrutura órfã cobrando** → cópia de segurança do estado, e remoção tratada como parte do procedimento, não como limpeza posterior.
- **Balanceador criado pelo cluster trava a remoção da rede** → ele não está no estado do provisionamento; removê-lo é pré-requisito da destruição.
- **Falha de obtenção de imagem por limite de consumo, diagnosticada como erro de referência** → autenticar no registro, ou reconhecer o sintoma. Agravado pela saída de rede única (D5).
- **Dependências de 2022 em runtimes de 2026** → só a construção e o boot provam; recuo para Node 22.
- **Runbook e `CLAUDE.md` ensinam procedimento que D1 torna obsoleto** → corrigir os dois faz parte desta mudança, não de um trabalho posterior. Um documento que ensina disciplina desnecessária faz a falha voltar a ser prevenida à mão.
- **`CLAUDE.md` afirma que `Dockerfile`, `k8s/` e `terraform/` existem em `HEAD`** → não existem; o último commit os removeu. A seção "Estado do working tree" precisa ser corrigida junto.
- **Falhas silenciosas da camada de deploy** → seletor desalinhado, configuração sem propagação e reinícios não observados não geram erro. Só verificação ativa pega, e ela é requisito, não recomendação.

## Migration Plan

Não há sistema em produção a migrar. A ordem de implementação decorre das dependências:

1. **Proteção primeiro** — padrões de exclusão no controle de versão, antes de qualquer inicialização de provisionamento
2. **Camada 1** — ambiente local e imagem multiplataforma publicada (sem dependências)
3. **Camada 3** — manifesto e validação em cluster local (depende da imagem publicada)
4. **Camada 2** — código de infraestrutura, com validação estática apenas (independente das outras; pode correr em paralelo à camada 3)
5. **Correção dos documentos** — runbook e `CLAUDE.md`

**Efeitos externos desta mudança.** Apenas dois, e nenhum deles gera custo recorrente:

| Operação | Efeito | Reversível? |
|---|---|---|
| Publicação da imagem no registro público | aditiva — identificações de versão nunca são reescritas | nada anterior é perdido |
| Criação e remoção do cluster local | containers na máquina de quem executa | `kind delete cluster` |

Nenhum recurso de nuvem é criado. Todo o resto é arquivo no repositório: remover o arquivo desfaz.

**Provisionamento futuro, quando for decidido.** Fora desta mudança, mas registrado para não se perder: `terraform apply` sobre o plano revisado, validação do ambiente, e — no encerramento — remover o serviço de exposição **antes** do `terraform destroy`. O balanceador é criado pelo controlador do cluster e não está no estado do provisionamento; destruir na ordem inversa trava a remoção da rede por interface pendente e deixa o balanceador cobrando.

## Open Questions

1. **Nada é validado na nuvem nesta rodada — nem a infraestrutura, nem o manifesto.** Com D10, a lacuna que antes cobria só o deploy passou a cobrir as duas camadas. Ficam sem cobertura: o provisionamento de fato funcionar (cota, permissão, disponibilidade por zona), o balanceador real e a eficácia da marcação de descoberta, a arquitetura `amd64` dos nós, a janela de aproximadamente 170 segundos até a primeira resposta, e o ciclo de remoção. A saída natural é uma mudança futura de "provisionamento e deploy em nuvem", executada quando houver decisão de gastar — ela consome o código e o manifesto que esta entrega produz, ambos já revisados e provados no que era possível provar sem custo.
2. **Esquema de versionamento da identificação de imagem** — adotado `v1.0.0`, derivado do campo de versão do manifesto de dependências. Não confirmado como convenção.
3. **Mitigação do limite de consumo do registro** — autenticar no cluster, obter previamente nos nós, ou apenas documentar o sintoma. Não decidido.
4. **Baselines de métrica ausentes** — sete métricas dos PRDs estão como "A levantar" por falta de medição registrada.
