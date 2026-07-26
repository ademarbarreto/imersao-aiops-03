---
prd_number: "003"
status: concluido-com-ressalva
priority: alta
created: 2026-07-26
issue: ""
depends_on: ["001"]
references:
  - ../runbook-deploy-kubernetes.md
  - https://kind.sigs.k8s.io/docs/user/quick-start/
  - https://kind.sigs.k8s.io/docs/user/loadbalancer/
  - https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
  - https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/
---

# PRD 003: Manifesto Kubernetes da aplicação, validado em cluster local

> **Situação em 2026-07-26 — CONCLUÍDO COM RESSALVA.** 11 de 12 critérios verificados pela mudança
> `containerizacao-infra-e-deploy`, num cluster `kind` local na mesma versão menor do EKS de destino.
> O critério de resposta pela exposição externa ficou **NÃO VERIFICADO**: por decisão do
> responsável, a validação local é por `kubectl port-forward` e o `EXTERNAL-IP` segue `<pending>`.
> O manifesto **não** foi adaptado para contornar — segue `type: LoadBalancer`. Evidências em `openspec/changes/containerizacao-infra-e-deploy/evidencias/relatorio-final.md`.

## 1. Contexto

- **Produto/área**: definição do deploy da aplicação `kube-news` em Kubernetes, consumindo a imagem publicada pelo PRD 001. É o artefato que descreve como a aplicação roda em um cluster.
- **Estado atual**: existe um deploy que já foi executado de verdade e está documentado no `docs/runbook-deploy-kubernetes.md`, com oito problemas reais registrados — cada um com sintoma, causa e correção. O que não existe é o conjunto de manifestos versionado no repositório, nem um caminho para exercitá-lo sem depender de um cluster na nuvem ligado e cobrando.
- **Problema**: dois. Primeiro, sem manifestos versionados o deploy depende de conhecimento tácito de quem já sofreu os problemas. Segundo, as falhas dessa camada são majoritariamente **silenciosas** — um seletor desalinhado retorna sucesso na aplicação e simplesmente não entrega tráfego; um contador de reinícios diferente de zero passa despercebido porque o estado exibido é "em execução". Nenhuma delas gera erro, e descobri-las num cluster na nuvem custa tempo e dinheiro.

> **Contexto técnico** (contrato da aplicação, regras de manifesto, os oito problemas conhecidos) vive no `docs/runbook-deploy-kubernetes.md`, na skill `manifestos-kubernetes` e no `CLAUDE.md`.

## 2. Solução Proposta

### Visão de produto

- O conjunto de manifestos que descreve o deploy da aplicação passa a existir no repositório, completo e aplicável de uma vez.
- Qualquer pessoa consegue subir um cluster Kubernetes na própria máquina e exercitar esse deploy — sem conta em nuvem, sem custo e sem esperar provisionamento.
- O manifesto é **provado**, não apenas escrito: a aplicação sobe, fica acessível e grava no banco dentro de um cluster de verdade.
- As falhas silenciosas conhecidas dessa camada têm verificação ativa, porque nenhuma delas se anuncia sozinha.
- O manifesto validado localmente é o **mesmo** que irá para a nuvem — nada é trocado para fazer o teste passar.

### Decisões de produto

1. **A validação acontece em um cluster local, não na nuvem.** Elimina custo e tempo de provisionamento do ciclo de escrita e correção do manifesto, e permite que quem acompanha o material exercite tudo sem uma conta de nuvem.
2. **O cluster local usa a mesma versão de Kubernetes de destino.** Validar numa versão diferente da que vai receber a aplicação enfraquece a validação.
3. **O manifesto não é adaptado para caber no ambiente local.** Se a exposição externa não funciona nativamente no cluster local, a resposta é dar ao ambiente local a capacidade que falta — não trocar a forma de exposição no manifesto. Trocar criaria um manifesto validado diferente do manifesto entregue.
4. **O banco continua dentro do cluster e sem armazenamento persistente.** Decisão de laboratório mantida: os dados são descartáveis e a perda ao recriar o banco é comportamento esperado. A consequência é tratada — a atualização do banco derruba o antigo antes de subir o novo, para nunca existirem dois bancos divergentes atendendo ao mesmo tempo.
5. **A senha do banco nunca fica no arquivo versionado.** O arquivo carrega um marcador e o valor entra no momento da aplicação.
6. **As duas verificações de saúde têm propósitos distintos de verdade.** A que decide reiniciar o processo nunca consulta o banco; a que decide receber tráfego, sim.
7. **O defeito de inicialização da aplicação é contornado nesta camada também**, com o start segurado até o banco responder — porque uma verificação de saúde não resolve um processo que termina antes de existir o que verificar.

> **Decisões arquiteturais duráveis identificadas neste PRD** — recomendo registrar como ADR via `escrever-trd` Modo Decision: (a) banco no cluster sem armazenamento persistente, em vez de banco gerenciado; (b) validação em cluster local em vez de ambiente de nuvem; (c) forma de exposição escolhida e o mecanismo que a viabiliza localmente.

### Fora do escopo

- **Publicar versão nova e reverter** — a definição do manifesto já garante o que torna isso possível (identificação de versão imutável, identificador fora do seletor), mas a operação em si não é exercitada por este PRD.
- **Alterar configuração e propagar a mudança** — o mecanismo de propagação faz parte da definição do manifesto, mas o ciclo operacional de alterá-la fica fora.
- **Aplicar e validar o manifesto no cluster da nuvem** — este PRD prova o manifesto localmente. A validação em nuvem não está coberta por nenhum PRD desta rodada; ver risco em §7.
- Camadas de template sobre os manifestos, como Helm ou Kustomize — o material trabalha com o manifesto direto.
- Entrada HTTP compartilhada, escalonamento automático, orçamento de interrupção e políticas de rede. *(premissa — confirme ou corrija)*
- Fluxo de entrega contínua e reconciliação automática a partir do repositório. *(premissa — confirme ou corrija)*
- Persistência de dados do banco — excluída por decisão explícita.
- Provisionamento do cluster de nuvem e construção da imagem — PRDs 002 e 001.
- Observabilidade e alertas. *(premissa — confirme ou corrija)*

## 3. Funcionalidades

> Os identificadores de US não são sequenciais porque US03 e US04 da versão anterior deste PRD saíram do escopo, e IDs já atribuídos não são reutilizados.

### US01: Definir e aplicar o conjunto de manifestos da aplicação

Como **pessoa que acompanha a imersão**, quero aplicar todo o deploy com um comando a partir do repositório, para colocar a aplicação no ar sem depender de conhecimento que não está escrito.

**Rules:**
- Todos os objetos do deploy vivem no repositório e são aplicados de uma vez, na ordem correta de dependência: o espaço isolado primeiro, a configuração antes das cargas de trabalho, o banco antes da aplicação.
- Todo objeto declara explicitamente o espaço isolado a que pertence — o destino nunca depende do contexto de quem executa o comando.
- Todo objeto carrega o conjunto padronizado de identificadores, de modo que uma única consulta traga a aplicação inteira e não uma parte dela.
- Todo componente executável declara quanto reserva e quanto pode consumir, de memória e de processamento, incluindo componentes auxiliares de inicialização.
- A aplicação só inicia após o banco aceitar conexões, verificado pelo próprio banco.
- Nenhuma variável de configuração é escrita diretamente na definição da carga de trabalho; nenhum valor real de credencial existe no arquivo versionado.
- A identificação da versão da imagem é imutável — nunca uma identificação que muda de conteúdo sem mudar de nome. O identificador de versão acompanha os rótulos, mas nunca entra no seletor, que é imutável após a criação.
- Alterar o conjunto de configuração provoca a atualização automática das cargas afetadas, sem depender de alguém lembrar de reiniciá-las.
- As duas verificações de saúde apontam para destinos diferentes, que a aplicação de fato serve; a que decide reiniciar não consulta o banco.
- A atualização do banco derruba o antigo antes de subir o novo.

**Edge cases:**
- O seletor que liga a exposição aos componentes não corresponde aos identificadores deles → a aplicação retorna sucesso, o serviço existe, e o tráfego simplesmente não chega. Exige verificação ativa da lista de destinos, que precisa ser não-vazia.
- A aplicação é aplicada antes de o banco estar pronto → o componente auxiliar de inicialização segura o start; sem ele, a aplicação termina, reinicia algumas vezes e "se resolve sozinha", mascarando o problema com reinícios silenciosos.
- Algum componente fica sem declaração de reserva de recursos → torna-se o primeiro candidato a remoção quando o node ficar sob pressão. A classe de serviço resultante nunca pode ser a de menor prioridade.
- A credencial real é gravada por engano no arquivo versionado → o repositório é público; a verificação de que o arquivo permanece com o marcador é parte do procedimento.
- Uma variável é declarada mas a aplicação não a lê → configuração decorativa; toda variável precisa existir no contrato real da aplicação.

### US02: Acessar a aplicação a partir da máquina, por fora do cluster

Como **pessoa acompanhando a demonstração**, quero acessar a aplicação pelo navegador, para ver o produto funcionando de verdade e não apenas o estado dos componentes.

**Rules:**
- A aplicação é exposta por um serviço externo, cujo tipo declara explicitamente essa intenção — a mesma forma que será usada na nuvem.
- O ambiente local recebe a capacidade necessária para atender esse tipo de exposição; o manifesto não é alterado para contornar uma limitação do ambiente de teste.
- Existe também um caminho de acesso direto, que funciona sem depender do mecanismo de exposição — usado para validar a aplicação mesmo quando a exposição está indisponível.
- A ligação entre a exposição e a porta da aplicação é feita pelo nome da porta, não pelo número repetido em dois lugares.

**Edge cases:**
- O endereço externo nunca é atribuído no cluster local → o ambiente local não recebeu a capacidade de atender esse tipo de exposição; é limitação conhecida do ambiente, não defeito do manifesto.
- Alguém troca a forma de exposição para o teste passar → o manifesto validado deixa de ser o manifesto entregue, e a falha reaparece só na nuvem. É explicitamente proibido pela decisão de produto 3.
- No ambiente de nuvem o endereço externo aparece mas a aplicação ainda não responde → é comportamento esperado; a medição real deste projeto foi de aproximadamente 170 segundos. Está fora do escopo deste PRD, mas registrado para não ser diagnosticado como defeito do manifesto.

### US05: Verificar que o deploy funcionou de verdade

Como **pessoa que opera a aplicação**, quero um conjunto de verificações que prove o funcionamento, para não concluir que está tudo certo com base em um estado que apenas informa que o processo não morreu.

**Rules:**
- Estado "em execução" não é aceito como prova de funcionamento.
- O contador de reinícios é parte obrigatória da verificação: valor diferente de zero em um deploy novo é um achado, não ruído.
- A lista de destinos de cada exposição precisa ser não-vazia — lista vazia é o sintoma exato de seletor desalinhado, e não gera erro.
- A verificação que prova o deploy é a que exercita o caminho completo até o banco, com escrita e leitura; consultar apenas a saúde do processo não prova conexão com o banco.
- A fonte da verdade sobre dados é o próprio banco. Quando o teste e o banco discordam, o banco está certo.
- A classe de serviço de cada componente é verificada e nunca pode ser a de menor prioridade.

**Edge cases:**
- A ferramenta de teste reporta falha e não há erro correspondente no registro da aplicação → medir de novo por outro caminho antes de abrir investigação. Já aconteceu neste projeto: o resultado negativo era ruído da ferramenta e o dado estava no banco.
- O banco é recriado e a aplicação termina uma vez → comportamento esperado e documentado, decorrente da decisão de não persistir dados e do defeito de inicialização. Não é incidente novo.
- Os dados de teste permanecem no banco após a verificação → poluição silenciosa; a limpeza faz parte do procedimento.

### US06: Subir um cluster local para validar o deploy

Como **pessoa que acompanha a imersão**, quero subir um cluster Kubernetes na minha própria máquina, para exercitar o deploy sem precisar de conta em nuvem, sem custo e sem esperar provisionamento.

**Rules:**
- A criação do cluster local parte de configuração versionada no repositório, não de comando digitado de memória.
- A versão de Kubernetes do cluster local é a mesma da versão de destino na nuvem.
- O cluster local recebe a capacidade de atender exposição externa, para que a mesma forma de exposição do manifesto de destino funcione ali.
- A imagem da aplicação usada é a mesma publicada pelo PRD 001, obtida do registro público — não uma construção local paralela.
- Criar e remover o cluster local são operações rápidas e sem custo, adequadas a um ciclo de correção do manifesto.

**Edge cases:**
- A máquina não tem recursos suficientes para o cluster e as cargas → a falha é reportada como limitação de recursos, com indicação do mínimo necessário. *(premissa — confirme ou corrija)*
- Os nodes locais têm arquitetura diferente dos nodes da nuvem → é atendido pela imagem multiplataforma do PRD 001, e passa a exercitar justamente a variante que a nuvem não exercita.
- A imagem não consegue ser obtida do registro público → verificar limite de consumo por origem antes de investigar a identificação da versão.
- O cluster local é removido → nenhum dado precisa sobreviver; o banco é descartável por decisão de produto.

## 4. Fluxo de Negócio

```
Pessoa quer exercitar o deploy
   │
   ▼
Sobe o cluster local a partir da configuração versionada (US06)
   │
   ▼
Cluster atende exposição externa? ──não──▶ recebe a capacidade que falta
   │ sim                                    (nunca: troca o manifesto)
   ▼
Aplica o manifesto (US01)
   │
   ▼
Objetos criados na ordem: espaço isolado ▶ configuração ▶ banco ▶ aplicação
   │
   ▼
Banco aceita conexões? ──não──▶ start da aplicação segurado (não falha)
   │ sim
   ▼
Lista de destinos da exposição está vazia? ──sim──▶ seletor desalinhado
   │ não                                             (sem erro visível)
   ▼
Contador de reinícios é zero? ──não──▶ investigar inicialização
   │ sim                                 (achado, não ruído)
   ▼
Escrita e leitura até o banco funcionam? ──não──▶ confirmar no banco
   │ sim                                            antes de investigar
   ▼
Aplicação acessível pelo navegador (US02) ──▶ manifesto provado (US05)
```

## 5. Critérios de Aceite

### 5a. Critérios de aceite da feature

| Critério | Razão de negócio | Como verificar (observável) |
|---|---|---|
| Um comando sobe o cluster local a partir da configuração versionada | é o que permite exercitar o deploy sem conta em nuvem e sem custo | executar a criação e obter um cluster com nodes prontos |
| A versão de Kubernetes do cluster local é a mesma da versão de destino na nuvem | validar em versão diferente da de destino enfraquece a validação | consultar a versão do cluster local e comparar com a fixada no PRD 002 |
| Um comando aplica todo o deploy e cria os objetos na ordem correta | ordem errada faz a aplicação subir antes de a configuração existir | aplicar o manifesto e conferir os objetos criados e sua ordem |
| O contador de reinícios é zero cinco minutos após um deploy novo | valor diferente de zero indica que o defeito de inicialização não foi contornado; o deploy "se resolve sozinho" e esconde o problema | consultar o contador de reinícios de cada componente |
| Nenhum componente está na classe de serviço de menor prioridade | significa componente sem declaração de recursos, primeiro a ser removido sob pressão do node | consultar a classe de serviço de cada componente |
| A lista de destinos de cada exposição é não-vazia | lista vazia é seletor desalinhado — falha silenciosa, sem erro em lugar nenhum | consultar os destinos de cada exposição |
| Um registro criado pela API é confirmado consultando o banco diretamente | é a única verificação que prova o caminho completo até o banco | criar registro pela API e consultar o banco |
| A aplicação responde pelo navegador a partir da máquina, através da exposição externa | prova que a forma de exposição escolhida funciona, e não apenas o acesso direto | requisitar a página pelo endereço da exposição |
| O manifesto aplicado no cluster local é idêntico ao que irá para a nuvem, exceto pela injeção da senha | manifesto adaptado para o teste passar valida um artefato que não é o entregue | comparar o arquivo versionado com o efetivamente aplicado |
| O arquivo versionado contém apenas o marcador de senha, nunca o valor real | o repositório é público | inspecionar o arquivo antes de cada envio |
| As duas verificações de saúde apontam para destinos diferentes, e a que reinicia não consulta o banco | se consultasse, um banco lento reiniciaria toda a frota em cascata e agravaria a carga sobre ele | inspecionar o manifesto e exercitar a indisponibilidade do banco |
| Os dados de teste são removidos ao final da verificação | evita poluição silenciosa do ambiente | contagem de registros antes e depois |

### 5b. Métricas de sucesso

| Métrica | Baseline (fonte) | Meta | Prazo | Mín. aceitável | Responsável |
|---|---|---|---|---|---|
| Reinícios de componentes em um deploy novo | 2 por componente (medição registrada no Problema 2 do runbook, antes da correção) | 0 | primeiro deploy com os manifestos versionados | 0 | Fabricio |
| Falhas silenciosas não detectadas pelo procedimento de verificação | 3 identificadas no deploy anterior — seletor desalinhado, configuração sem propagação, reinícios não observados | 0 | idem | 0 | Fabricio |
| Custo para exercitar uma correção no manifesto | custo de um cluster de nuvem ligado durante o ciclo de correção (valor A levantar) *(premissa — confirme ou corrija)* | 0 | primeira validação local | 0 | Fabricio |
| Tempo entre alterar o manifesto e ter o resultado observável | A levantar — hoje depende de um cluster de nuvem disponível *(premissa — confirme ou corrija)* | < 3 minutos | idem | < 8 minutos | Fabricio |
| Ocorrências de credencial real enviada ao repositório | 0 (nenhuma registrada) | 0 | permanente | 0 | Fabricio |

## 6. Milestones

### Milestone 1: Manifesto definido e provado em cluster local

**Por que é um marco:** é quando o deploy deixa de ser conhecimento tácito de quem já sofreu os oito problemas e vira um artefato versionado que qualquer pessoa aplica — e, principalmente, **prova** na própria máquina, sem conta em nuvem e sem custo. Anuncia-se como "o deploy inteiro está no repositório e você consegue rodar hoje". É também o que remove o custo de errar: corrigir o manifesto passa a custar minutos em vez de um cluster ligado.

**Funcionalidades:** US01, US02, US05, US06

**Checklist de aceite** (marcado pelo Aprovador após a implementação):
- [x] Um comando sobe o cluster local a partir da configuração versionada
- [x] A versão de Kubernetes do cluster local é a mesma da versão de destino na nuvem
- [x] Um comando aplica todo o deploy, criando os objetos na ordem correta
- [x] O contador de reinícios é zero cinco minutos após o deploy
- [x] Nenhum componente está na classe de serviço de menor prioridade
- [x] A lista de destinos de cada exposição é não-vazia
- [x] Um registro criado pela API é confirmado consultando o banco diretamente
- [ ] A aplicação responde pelo navegador através da exposição externa  
      **NÃO VERIFICADO** — por decisão do responsável, `cloud-provider-kind` foi dispensado e a validação local passou a ser por `kubectl port-forward`, com o `EXTERNAL-IP` permanecendo `<pending>`. A aplicação responde por port-forward em `/`, `/health`, `/ready`, nos estáticos e em `POST /api/post` — o que prova aplicação, Service e seletor, mas **não** a atribuição de endereço externo. O manifesto **não** foi alterado: segue `type: LoadBalancer`, e o critério fecha no EKS.
- [x] O manifesto aplicado é idêntico ao versionado, exceto pela injeção da senha
- [x] O arquivo versionado contém apenas o marcador de senha
- [x] As duas verificações de saúde apontam para destinos diferentes, e a que reinicia não consulta o banco
- [x] Os dados de teste foram removidos ao final

**Aprovador:** Fabricio

## 7. Riscos e Dependências

| Risco | Impacto | Mitigação | Status |
|---|---|---|---|
| **Nenhum PRD desta rodada valida o manifesto no cluster de nuvem.** O que fica sem cobertura: o mecanismo real de exposição externa e sua marcação de descoberta de rede, a arquitetura dos nodes da nuvem, e a janela de espera até a primeira resposta | Alto — a validação local passa e a diferença aparece só no primeiro deploy real | declarar explicitamente a lacuna; decidir se ela vira um PRD próprio ou entra como escopo adicional do PRD 002 | Pendente |
| Falhas desta camada são silenciosas — nenhuma gera erro | Alto — deploy considerado bom enquanto não entrega tráfego | verificação ativa obrigatória em US05, cobrindo os três sintomas conhecidos | Pendente |
| A exposição externa exige uma capacidade que o cluster local não tem nativamente | Médio — se resolvida trocando a forma de exposição, o manifesto validado deixa de ser o entregue | decisão de produto 3 proíbe a troca; a capacidade é dada ao ambiente, não retirada do manifesto | Pendente |
| Perda de dados ao recriar o banco | Médio — aceito por decisão de laboratório | comportamento documentado como esperado; a atualização derruba o banco antigo antes de subir o novo | Mitigado |
| Falha ao obter a imagem diagnosticada como erro de identificação de versão | Médio | limite de consumo por origem verificado primeiro | Monitorando |
| O runbook e as instruções do projeto ensinam um procedimento de construção de imagem que o PRD 001 torna obsoleto | Médio — o material passa a ensinar disciplina desnecessária | atualizar os dois documentos como parte da entrega deste PRD | Pendente |
| O componente auxiliar de inicialização usa uma versão de banco diferente da adotada no PRD 001 | Baixo — funcionaria, mas é ruído em material didático | alinhar as versões | Pendente |

**Dependências:**

| Dependência | Tipo | Status | Impacto se bloqueado |
|---|---|---|---|
| PRD 001 — imagem multiplataforma publicada e versionada | Interna | Rascunho | bloqueia o milestone: não há o que implantar, e a variante local de arquitetura não existiria |
| Ferramenta de cluster local instalada na máquina | Externa | Disponível | bloqueia US06 e, por consequência, toda a validação |
| Decisão de manter o banco no cluster sem persistência | Interna | Decidida | se revertida, US01 e US05 mudam e um risco deixa de existir |

## 8. Referências

- [`docs/runbook-deploy-kubernetes.md`](../runbook-deploy-kubernetes.md) — os oito problemas reais deste projeto; são a origem da maior parte das regras e edge cases deste PRD
- [kind — Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/) — criação do cluster local e a versão de Kubernetes que ele entrega por padrão; consultado em 2026-07-26
- [kind — LoadBalancer](https://kind.sigs.k8s.io/docs/user/loadbalancer/) — a exposição externa não funciona nativamente no cluster local e exige uma capacidade adicional; é a base da decisão de produto 3
- [Rótulos recomendados — Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) — o conjunto padronizado de identificadores exigido em US01
- [Verificações de saúde — Kubernetes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/) — a distinção entre reiniciar e receber tráfego, base da decisão de produto 6
- PRD 001 — produz a imagem consumida aqui
- PRD 002 — provisiona o cluster de nuvem de destino; **não** é pré-requisito deste PRD, porque a validação é local

## 9. Registro de Decisões

- **[2026-07-26]:** Escopo reduzido para definição do manifesto mais validação em cluster local. Motivo: decisão do responsável. Saíram do escopo as operações do dia a dia — publicar versão nova com reversão, e alterar configuração com propagação. As **regras** que tornam essas operações possíveis permanecem na definição do manifesto (identificação de versão imutável, identificador fora do seletor, mecanismo de propagação de configuração); apenas o exercício operacional delas saiu.
- **[2026-07-26]:** Validação em cluster local em vez de cluster de nuvem. Motivo: remove custo e tempo de provisionamento do ciclo de correção do manifesto, e permite que quem acompanha o material exercite tudo sem conta em nuvem.
- **[2026-07-26]:** O cluster local usa a mesma versão de Kubernetes de destino. Motivo: validar em versão diferente da de destino enfraquece a validação sem economizar nada.
- **[2026-07-26]:** O manifesto não é adaptado para caber no ambiente local. Motivo: trocar a forma de exposição para o teste passar produziria um manifesto validado diferente do entregue, e a falha reapareceria apenas na nuvem — exatamente o tipo de divergência que a validação existe para evitar.
- **[2026-07-26]:** `depends_on` alterado de `["001", "002"]` para `["001"]`. Critério: com a validação acontecendo localmente, este PRD deixa de pressupor o cluster de nuvem, sua rede e sua marcação de descoberta. A única dependência real que resta é a imagem publicada pelo PRD 001. Consequência registrada como o risco de maior severidade em §7: ninguém valida o manifesto na nuvem nesta rodada.
- **[2026-07-26]:** Banco mantido no cluster e sem armazenamento persistente. Motivo: decisão de laboratório reafirmada pelo responsável. Consequências aceitas: perda de dados ao recriar o banco, e necessidade de derrubar o banco antigo antes de subir o novo.
- **[2026-07-26]:** Senha nunca fica no arquivo versionado. Motivo: o repositório é público, e o mecanismo padrão de segredo do Kubernetes é codificação, não proteção.
- **[2026-07-26]:** O contorno do defeito de inicialização é repetido nesta camada. Motivo: consequência direta da decisão do PRD 001 de não corrigir o código.
- **[2026-07-26]:** Atualizar o runbook e as instruções do projeto faz parte da entrega. Motivo: ambos ensinam um procedimento de construção de imagem por arquitetura que o PRD 001 torna obsoleto.
