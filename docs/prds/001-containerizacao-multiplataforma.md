---
prd_number: "001"
status: concluido
priority: alta
created: 2026-07-26
issue: ""
depends_on: []
references:
  - https://docs.docker.com/build/building/multi-platform/
  - https://docs.docker.com/build/builders/drivers/
  - https://github.com/nodejs/Release
  - https://www.postgresql.org/support/versioning/
  - ../runbook-deploy-kubernetes.md
---

# PRD 001: Containerização e publicação multiplataforma do kube-news

> **Situação em 2026-07-26 — CONCLUÍDO.** 12 de 12 critérios de aceite verificados pela mudança
> `containerizacao-infra-e-deploy`. Imagem publicada: `fabricioveronez/kube-news:v1.0.0`
> (`linux/amd64` + `linux/arm64`). Evidências em `openspec/changes/containerizacao-infra-e-deploy/evidencias/relatorio-final.md`.

## 1. Contexto

- **Produto/área**: `kube-news`, portal de notícias em Node/Express usado como aplicação-alvo da imersão de AIOps. A aplicação é estável; o trabalho está nos artefatos de infraestrutura em volta dela.
- **Estado atual**: a aplicação só roda em uma máquina que já tenha Node e PostgreSQL instalados e configurados. Não existe artefato distribuível: quem acompanha o material precisa reproduzir o ambiente à mão, e o artefato que o cluster consome é produzido manualmente, com uma flag de arquitetura que alguém precisa lembrar de digitar.
- **Problema**: dois custos concretos. Primeiro, o tempo de setup de cada pessoa que segue o material, e a divergência de ambiente que ele produz. Segundo — e mais caro — a imagem construída na arquitetura errada atravessa build, push e apply sem nenhuma reclamação e só falha dentro do cluster, com `exec format error`. Isso já aconteceu neste projeto e está registrado como Problema 1 do runbook de deploy.

> **Contexto técnico** (stack, versões, contrato da aplicação) vive no `CLAUDE.md` e no `docs/runbook-deploy-kubernetes.md`.

## 2. Solução Proposta

### Visão de produto

- Quem clona o repositório sobe a aplicação **e o banco** com um único comando, sem instalar Node nem PostgreSQL e sem preencher arquivo de configuração.
- Existe uma imagem publicada e pública que roda em qualquer arquitetura de node, eliminando por construção a classe de falha de arquitetura em vez de preveni-la por disciplina.
- Cada versão publicada é identificável e a anterior continua recuperável.
- O defeito conhecido de inicialização da aplicação (ela termina se o banco não responder no start) é contornado pela ordenação da subida, não escondido.

### Decisões de produto

1. **Imagem pública no Docker Hub, em `fabricioveronez/kube-news`.** É aplicação de demonstração, sem nada a proteger, e repositório público dispensa credencial de quem segue o material.
2. **Tag versionada e nunca reaproveitada.** Permite responder "qual versão está rodando" olhando o manifesto, e é o que dá a um rollback para onde voltar.
3. **Zero configuração no ambiente local.** O caminho feliz não pode depender de um arquivo `.env` que a pessoa precise criar; os valores padrão do ambiente local são exatamente os que a aplicação já assume.
4. **O defeito de inicialização não é corrigido, é contornado.** Foi classificado como bug conhecido e aceito. A consequência é explícita: o contorno se repete em cada ambiente novo.
5. **O ambiente local e a imagem publicada são caminhos separados**, com propósitos diferentes — um serve o ciclo de desenvolvimento, o outro serve o cluster.

> **Decisões arquiteturais duráveis identificadas neste PRD** — recomendo registrar como ADR via `escrever-trd` Modo Decision: (a) imagem multiplataforma em vez de build por arquitetura; (b) escolha da imagem base e da versão de runtime; (c) separação entre o caminho de build local e o de publicação.

### Fora do escopo

- Pipeline de CI/CD para build e publicação — a publicação é manual nesta etapa. *(premissa — confirme ou corrija)*
- Varredura de vulnerabilidades e assinatura da imagem — não há requisito de cadeia de suprimentos nesta etapa. *(premissa — confirme ou corrija)*
- Desenvolvimento com código editável dentro do container (hot-reload) — descartado por decisão explícita; a imagem é sempre imutável.
- Correção do código da aplicação, incluindo o defeito de inicialização e a alteração de schema no boot.
- Manifestos Kubernetes e provisionamento de infraestrutura — cobertos pelos PRDs 003 e 002.

## 3. Funcionalidades

### US01: Subir a stack completa localmente em um comando

Como **pessoa que acompanha a imersão**, quero subir a aplicação e o banco com um único comando, para conseguir usar o produto sem instalar nem configurar dependência nenhuma na minha máquina.

**Rules:**
- O comando de subida funciona a partir de um clone limpo do repositório, sem nenhum arquivo de configuração criado à mão.
- Os valores padrão do ambiente local são idênticos aos que a aplicação já assume no código; o único valor que muda é o endereço do banco, que deixa de ser local e passa a ser o serviço do banco.
- A aplicação só inicia depois que o banco estiver aceitando conexões — não basta o banco ter começado a subir.
- O banco preserva os dados entre paradas e subidas do ambiente local.
- A aplicação é alcançável a partir da máquina do usuário, não apenas de dentro do ambiente.

**Edge cases:**
- A porta usada pela aplicação já está ocupada na máquina → a subida falha com mensagem clara sobre o conflito de porta, e é possível subir em outra porta sem editar o repositório. *(premissa — confirme ou corrija)*
- O banco demora mais que o normal para aceitar conexões → a aplicação continua esperando em vez de falhar; a subida só é considerada com erro após uma janela de tolerância. *(premissa — confirme ou corrija)*
- Existe um ambiente antigo do mesmo projeto rodando na máquina → o conflito é reportado antes de qualquer remoção, e nenhum dado é apagado sem confirmação.
- O usuário para o ambiente e sobe de novo → os dados criados antes continuam lá.

### US02: Publicar uma versão da imagem que roda em qualquer arquitetura

Como **pessoa responsável pelo material**, quero publicar uma imagem que funcione tanto na minha máquina quanto nos nodes do cluster, para que ninguém precise lembrar de uma flag de arquitetura e para que o erro de arquitetura deixe de existir.

**Rules:**
- A imagem publicada atende às duas arquiteturas alvo — a da máquina de quem desenvolve e a dos nodes do cluster — sob a **mesma** referência de versão.
- Cada arquitetura é construída de forma independente; nenhum resultado de construção é reaproveitado entre elas.
- Toda versão publicada recebe uma identificação própria; uma identificação já publicada nunca é reescrita com conteúdo diferente.
- O repositório publicado é público, e consumir a imagem não exige credencial.
- Nenhum segredo, histórico de versionamento ou dependência instalada na máquina de quem publica entra na imagem.

**Edge cases:**
- Alguém tenta publicar reaproveitando uma identificação de versão já existente → a operação é tratada como erro de procedimento, porque quebra a capacidade de rollback e de saber o que está rodando.
- A publicação falha por falta de autenticação no registro → o procedimento indica a autenticação como pré-requisito antes de qualquer nova tentativa.
- Uma das arquiteturas falha na construção → nada é publicado; publicar apenas uma arquitetura reintroduz exatamente a falha que este PRD elimina.
- No futuro, a aplicação passa a depender de um componente que precisa ser compilado para cada arquitetura → a construção independente por arquitetura continua correta, sem mudança de procedimento.

### US03: Ter a inicialização protegida contra o banco indisponível

Como **pessoa que opera o ambiente**, quero que a aplicação não termine quando o banco ainda não está pronto, para não precisar diagnosticar um erro cuja causa é apenas ordem de subida.

**Rules:**
- A aplicação só é iniciada após o banco confirmar que aceita conexões, verificado pelo próprio banco e não por tempo de espera fixo.
- A verificação de prontidão do banco considera o banco e o usuário que a aplicação realmente usa, não um padrão genérico.
- O contorno é documentado como contorno, com o defeito de origem nomeado — para que ninguém o interprete como comportamento normal da aplicação.

**Edge cases:**
- O banco cai depois que a aplicação já subiu → a aplicação termina, e isso é comportamento esperado e documentado, não incidente novo. A recuperação é a reinicialização.
- O banco nunca fica pronto → a espera é limitada e a falha é reportada apontando o banco, não a aplicação.

## 4. Fluxo de Negócio

```
Pessoa clona o repositório
   │
   ▼
Quer usar a aplicação localmente?
   ├── sim ──▶ Sobe o ambiente com um comando
   │             │
   │             ▼
   │          Banco aceita conexões? ──não──▶ Aguarda (não falha)
   │             │ sim
   │             ▼
   │          Aplicação inicia ──▶ Acessível na máquina, com dados preservados
   │
   └── não, quer publicar para o cluster
                 │
                 ▼
              Constrói cada arquitetura independentemente
                 │
                 ▼
              Todas as arquiteturas OK? ──não──▶ Não publica nada
                 │ sim
                 ▼
              Publica sob uma identificação de versão nova
                 │
                 ▼
              Cluster consome sem depender de arquitetura
```

## 5. Critérios de Aceite

### 5a. Critérios de aceite da feature

| Critério | Razão de negócio | Como verificar (observável) |
|---|---|---|
| A partir de um clone limpo, um único comando sobe aplicação e banco, sem nenhum arquivo de configuração criado à mão | é a promessa central do material; se exigir passo manual, o setup volta a divergir por pessoa | executar o comando num clone novo e obter resposta HTTP 200 na página inicial, a partir do host |
| Todos os recursos estáticos da página inicial respondem com sucesso **e com o tipo de conteúdo correto** | página que abre com todo o CSS quebrado é o modo de falha silencioso mais comum desta classe de artefato | requisitar cada recurso referenciado pela página e conferir status e tipo de conteúdo |
| Um registro criado pela API é lido de volta pela API **e confirmado direto no banco** | prova o caminho completo aplicação → banco; verificar só a página inicial não prova conexão | criar registro, ler pela API, consultar o banco diretamente |
| O registro criado sobrevive a parar e subir o ambiente | sem isso o ambiente local perde dados a cada ciclo e deixa de servir para demonstrar comportamento | parar e subir o ambiente (sem remover volumes) e reconsultar |
| A imagem publicada atende às duas arquiteturas sob a mesma referência de versão | é o requisito que elimina o `exec format error` por construção | inspecionar o manifesto publicado e confirmar as duas arquiteturas |
| O processo dentro do container não roda como administrador | reduz o impacto de uma falha da aplicação | inspecionar o usuário efetivo do processo em execução |
| A parada do ambiente retorna em menos de 10 segundos | parada que leva exatamente 10s indica que o sinal de término não chegou ao processo, e no cluster isso vira encerramento abrupto | cronometrar a parada |
| Após 30 segundos de execução, o contador de reinícios do container é zero | reinício silencioso é sintoma do defeito de inicialização não contornado | consultar o contador de reinícios |
| Nenhum segredo, histórico de versionamento ou dependência local entra na imagem | a imagem é pública | inspecionar o conteúdo da imagem publicada |

### 5b. Métricas de sucesso

| Métrica | Baseline (fonte) | Meta | Prazo | Mín. aceitável | Responsável |
|---|---|---|---|---|---|
| Ocorrências de falha por arquitetura de imagem | 1 ocorrência registrada (Problema 1 do `runbook-deploy-kubernetes.md`) | 0 | a partir da primeira publicação multiplataforma | 0 | Fabricio |
| Tempo até a aplicação responder localmente, a partir de um clone limpo | A levantar — hoje envolve instalar Node e PostgreSQL à mão, sem medição registrada *(premissa — confirme ou corrija)* | < 5 minutos | primeira turma que usar o material | < 10 minutos | Fabricio |
| Passos manuais de configuração antes da primeira subida | A levantar *(premissa — confirme ou corrija)* | 0 | idem | 0 | Fabricio |

## 6. Milestones

### Milestone 1: Ambiente local reproduzível

**Por que é um marco:** a partir dele, qualquer pessoa usa o produto sem instalar nada e sem configurar nada. É o que se anuncia para a turma como "clona e roda" — e é o pré-requisito de todo o resto do material.

**Funcionalidades:** US01, US03

**Checklist de aceite** (marcado pelo Aprovador após a implementação):
- [x] Um único comando, a partir de clone limpo, sobe aplicação e banco sem configuração manual
- [x] A página inicial responde com sucesso a partir da máquina do usuário
- [x] Todos os recursos estáticos respondem com sucesso e com o tipo de conteúdo correto
- [x] Um registro criado pela API é confirmado direto no banco
- [x] O registro sobrevive a parar e subir o ambiente
- [x] O contador de reinícios do container é zero após 30 segundos
- [x] A parada do ambiente retorna em menos de 10 segundos

**Aprovador:** Fabricio

### Milestone 2: Imagem multiplataforma publicada

**Por que é um marco:** é a entrega que faz o erro de arquitetura deixar de existir, em vez de continuar sendo prevenido por disciplina de quem digita o comando. Sem ela, o PRD 003 não tem o que consumir.

**Funcionalidades:** US02

**Checklist de aceite** (marcado pelo Aprovador após a implementação):
- [x] O manifesto publicado atende às duas arquiteturas sob a mesma referência de versão
- [x] Consumir a imagem não exige credencial
- [x] O processo dentro do container não roda como administrador
- [x] Nenhum segredo, histórico de versionamento ou dependência local está presente na imagem
- [x] A identificação de versão publicada não reaproveita nenhuma anterior

**Aprovador:** Fabricio

## 7. Riscos e Dependências

| Risco | Impacto | Mitigação | Status |
|---|---|---|---|
| As dependências da aplicação estão travadas em versões de 2022 e podem não funcionar bem em runtimes atuais | Alto — bloqueia os dois milestones | validar na construção e na primeira execução; se houver atrito, descer para a versão de runtime anterior ainda suportada | Pendente |
| Consumo da imagem pública é limitado por origem, e uma sala inteira compartilha a mesma saída de rede | Médio — falha de download no meio da aula, com sintoma que parece erro de configuração | autenticar antes de consumir, ou reconhecer o sintoma; conferir o limite vigente na véspera | Monitorando |
| A alteração de schema executada na inicialização torna a atualização de versão arriscada | Médio | comportamento herdado da aplicação e fora do escopo deste PRD; documentado para não ser diagnosticado como defeito do container | Monitorando |
| A otimização de compartilhar dependências entre arquiteturas volta a ser proposta no futuro | Baixo | decisão registrada: cada arquitetura é independente, justamente para não criar falha que só aparece em execução | Mitigado |

**Dependências:**

| Dependência | Tipo | Status | Impacto se bloqueado |
|---|---|---|---|
| Conta no Docker Hub com permissão de publicação em `fabricioveronez/kube-news` | Externa | Disponível | bloqueia o Milestone 2 |
| Decisão de não corrigir o defeito de inicialização da aplicação | Interna | Decidida | se revertida, US03 deixa de ser necessária e o contorno sai dos três PRDs |

## 8. Referências

- [Multi-platform builds — Docker](https://docs.docker.com/build/building/multi-platform/) — define a restrição de que uma imagem multiplataforma não é armazenável localmente pelo mecanismo padrão, o que separa o caminho local do de publicação
- [Build drivers — Docker](https://docs.docker.com/build/builders/drivers/) — o construtor padrão não atende a múltiplas arquiteturas
- [Node.js Release Working Group](https://github.com/nodejs/Release) — suporte vigente do runtime, consultado em 2026-07-26
- [PostgreSQL Versioning Policy](https://www.postgresql.org/support/versioning/) — versões com suporte, consultado em 2026-07-26
- [`docs/runbook-deploy-kubernetes.md`](../runbook-deploy-kubernetes.md) — Problema 1 (arquitetura da imagem) e Problema 2 (inicialização sem banco) são as duas falhas reais que motivam US02 e US03
- PRD 003 — consome a imagem publicada por este PRD

## 9. Registro de Decisões

- **[2026-07-26]:** Publicar em repositório público. Motivo: aplicação de demonstração sem nada a proteger, e repositório público elimina a necessidade de credencial para quem segue o material.
- **[2026-07-26]:** Cada arquitetura é construída independentemente, sem reaproveitar resultado entre elas. Motivo: reaproveitar é mais rápido hoje porque nenhuma dependência precisa ser compilada, mas produziria uma falha que só aparece em execução no cluster caso isso mude — a mesma assinatura do erro que este PRD elimina.
- **[2026-07-26]:** O defeito de inicialização não será corrigido no código. Motivo: classificado pelo responsável como bug conhecido. Consequência registrada: o contorno passa a ser permanente e se repete em cada ambiente novo.
- **[2026-07-26]:** O ambiente local e a imagem publicada são caminhos separados. Motivo: o mecanismo padrão não armazena imagem multiplataforma localmente; tentar unificar quebraria a promessa de subida em um comando.
- **[2026-07-26]:** `depends_on` vazio. Motivo: este é o primeiro artefato da cadeia — não pressupõe comportamento descrito em nenhum outro PRD.
