---
prd_number: "002"
status: rascunho
priority: alta
created: 2026-07-26
issue: ""
depends_on: []
references:
  - https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html
  - https://endoflife.date/amazon-eks
  - https://registry.terraform.io/providers/hashicorp/aws/latest
  - ../runbook-deploy-kubernetes.md
---

# PRD 002: Provisionamento do cluster EKS como código

## 1. Contexto

- **Produto/área**: infraestrutura de execução da imersão de AIOps. É o ambiente onde a aplicação `kube-news` roda, e é também objeto de ensino — o material mostra a infraestrutura sendo criada, não apenas usada.
- **Estado atual**: o cluster existe como ambiente de referência descrito no runbook de deploy (`kube-news-dev`, em `us-east-1`, com dois nodes), mas não há hoje, no repositório, código versionado que o recrie. Quem acompanha o material não tem como reproduzir o ambiente, e não há forma confiável de remover tudo depois.
- **Problema**: três custos. Um ambiente que não nasce de código não é reproduzível nem auditável — a diferença entre o que está documentado e o que existe de fato só aparece quando algo quebra. Sem código, também não há caminho confiável de remoção: os componentes cobram por hora, ligados, independentemente de uso, e removê-los à mão pelo console deixa sobras. E sem reprodutibilidade, cada participante depende de o instrutor ter o ambiente de pé.

> **Contexto técnico** (estrutura de módulos, versões de provedor, convenções) vive na skill `terraform-boas-praticas` e no `CLAUDE.md`.

## 2. Solução Proposta

### Visão de produto

- O ambiente inteiro nasce de código versionado: quem clona o repositório consegue criar um cluster equivalente ao do material, sem passo manual no console.
- O ambiente pode ser removido por inteiro com um comando, para que o custo pare quando o laboratório não estiver em uso.
- A separação entre a definição de *como* a infraestrutura é construída e *quais valores* cada ambiente usa fica explícita, para que criar um segundo ambiente seja copiar uma pasta e trocar valores.
- A infraestrutura fica preparada para receber a aplicação: a rede já traz o que o cluster precisa para expor um serviço ao mundo, sem intervenção posterior.

### Decisões de produto

1. **Um único ambiente, `dev`.** Não há requisito de homologação ou produção nesta etapa; ambiente novo é pasta nova, quando existir.
2. **O estado do provisionamento fica na máquina de quem executa.** Há um operador só, e a alternativa exigiria criar antes um repositório de estado compartilhado — passo extra sem benefício aqui. A contrapartida é registrada como risco: perder o estado significa perder a capacidade de remover o ambiente pelo código.
3. **Os nodes ficam em rede privada.** Decisão consciente de custo *versus* postura: é a topologia correta e mais cara, escolhida em vez da alternativa mais barata de expor os nodes diretamente.
4. **Nenhum componente de terceiros no caminho crítico do provisionamento.** Todo bloco reutilizável é escrito e mantido no próprio repositório.
5. **A remoção do ambiente é procedimento de primeira classe**, com pré-requisito explícito — não uma limpeza opcional feita no fim.

> **Decisões arquiteturais duráveis identificadas neste PRD** — recomendo registrar como ADR via `escrever-trd` Modo Decision: (a) estado do provisionamento local em vez de remoto; (b) nodes em rede privada com saída pela rede, em vez de nodes expostos; (c) separação de responsabilidade entre o provisionamento da infraestrutura e a aplicação dos manifestos, que ficam em ferramentas distintas.

### Fora do escopo

- Ambientes além de `dev` — não há requisito hoje.
- Banco de dados gerenciado. O banco continua rodando dentro do cluster, por decisão explícita; ver PRD 003.
- Pipeline de CI/CD executando o provisionamento — a execução é manual nesta etapa. *(premissa — confirme ou corrija)*
- Aplicação dos manifestos da aplicação pela mesma ferramenta de provisionamento — decisão explícita de manter as duas responsabilidades separadas.
- Registro de imagens gerenciado na nuvem — a publicação usa o Docker Hub; ver PRD 001.
- Observabilidade, backup, e política de acesso além do necessário para operar o laboratório. *(premissa — confirme ou corrija)*

## 3. Funcionalidades

### US01: Criar o ambiente completo a partir do código

Como **pessoa que acompanha a imersão**, quero criar um cluster equivalente ao do material rodando um comando sobre o código do repositório, para conseguir seguir as aulas no meu próprio ambiente sem depender do ambiente de outra pessoa.

**Rules:**
- A criação parte de um clone limpo do repositório, sem nenhum passo manual no console da nuvem.
- O código está organizado de modo que a definição de *como* cada capacidade de infraestrutura é construída fica separada dos *valores* que o ambiente usa; a definição de um ambiente é uma lista de capacidades com seus valores, não uma coleção de recursos soltos.
- Cada ambiente é uma pasta com seus próprios valores e seu próprio estado. A diferença entre dois ambientes é legível comparando seus arquivos de valores.
- As versões das ferramentas e provedores usados são fixadas explicitamente e conferidas na origem no momento em que são escritas, nunca reproduzidas de memória.
- Nenhum bloco reutilizável vem de fora do repositório.
- A versão do Kubernetes escolhida está dentro do suporte padrão do provedor de nuvem.
- O estado do provisionamento e os arquivos locais gerados nunca entram no controle de versão; o arquivo que fixa as versões resolvidas, sim.

**Edge cases:**
- Quem executa não tem permissão suficiente na nuvem → a criação falha antes de criar qualquer coisa, sem deixar recursos parciais cobrando. *(premissa — confirme ou corrija)*
- Uma quota da conta é atingida no meio da criação → o que já foi criado permanece registrado no estado, e uma nova execução continua de onde parou em vez de recomeçar.
- Alguém copia um exemplo com versão de Kubernetes fora do suporte → a versão fixada no código prevalece; o valor não é herdado de exemplo externo.
- Duas pessoas executam a criação a partir do mesmo código → cada uma cria seu próprio ambiente independente, porque o estado é local a quem executa.

### US02: Ter a rede preparada para expor a aplicação ao mundo

Como **pessoa que vai fazer o deploy da aplicação**, quero que a rede já venha pronta para que o cluster consiga publicar um serviço externo, para não descobrir a falta de uma configuração de rede só quando a exposição não funcionar.

**Rules:**
- A rede contempla áreas públicas e privadas, distribuídas em pelo menos duas zonas de disponibilidade, atendendo ao mínimo exigido pelo serviço de cluster.
- Os nodes ficam nas áreas privadas e alcançam a internet por uma saída controlada — o que é necessário para que consigam obter as imagens da aplicação.
- As áreas de rede carregam a marcação que o cluster usa para descobrir onde publicar um serviço externo. Sem ela, a exposição fica pendente indefinidamente, sem erro em lugar nenhum.
- Nenhum node é diretamente alcançável a partir da internet.

**Edge cases:**
- A marcação de descoberta de rede está ausente ou errada → a exposição da aplicação nunca completa, e o sintoma aparece no PRD 003, longe da causa. Este é o Problema 5 registrado no runbook; a marcação é responsabilidade deste PRD.
- A saída controlada da rede privada fica indisponível → os nodes deixam de conseguir obter imagens novas; os já obtidos continuam funcionando.
- Todo o tráfego de saída do cluster passa por um único endereço → limites de consumo contados por origem passam a valer para o cluster inteiro somado. Ver risco correspondente em §7.

### US03: Remover o ambiente por inteiro para parar o custo

Como **pessoa responsável pelo material**, quero remover tudo o que foi criado com um comando, para que o laboratório não continue cobrando quando não estiver em uso.

**Rules:**
- A remoção é procedimento documentado de primeira classe, com seus pré-requisitos explícitos — não uma limpeza opcional.
- Componentes criados por dentro do cluster, e não pelo provisionamento, precisam ser removidos **antes**: eles não estão registrados no estado e podem impedir a remoção da rede.
- Ao final, nenhum componente cobrado permanece ativo.

**Edge cases:**
- A remoção é executada sem remover antes o que o cluster criou por conta própria → a remoção da rede trava por dependência pendente, e sobra um componente cobrando. É o motivo de o pré-requisito existir.
- O estado do provisionamento foi perdido → a remoção pelo código deixa de ser possível e sobra infraestrutura cobrando, removível apenas manualmente. Ver risco em §7.
- A remoção é interrompida no meio → executá-la novamente conclui o que faltou, a partir do estado.

## 4. Fluxo de Negócio

```
Pessoa quer o ambiente do laboratório
   │
   ▼
Executa a criação a partir do código
   │
   ▼
Rede criada (áreas pública e privada, 2 zonas, marcações de descoberta)
   │
   ▼
Cluster e nodes criados nas áreas privadas
   │
   ▼
Ambiente pronto ──▶ PRD 003 faz o deploy da aplicação
   │
   ▼
Laboratório encerrado?
   ├── não ──▶ ambiente segue cobrando por hora
   └── sim ──▶ Removeu antes o que o cluster criou por conta própria?
                 ├── não ──▶ remoção trava, sobra componente cobrando
                 └── sim ──▶ Remoção completa ──▶ custo zerado
```

## 5. Critérios de Aceite

### 5a. Critérios de aceite da feature

| Critério | Razão de negócio | Como verificar (observável) |
|---|---|---|
| A criação, a partir de clone limpo, entrega um cluster utilizável sem nenhum passo manual no console | é a promessa de reprodutibilidade do material | após a criação, listar os nodes do cluster e obter dois nodes em estado pronto |
| Nenhum node possui endereço alcançável a partir da internet | postura de rede escolhida explicitamente; se falhar, a decisão de custo foi paga sem receber o benefício | inspecionar os endereços atribuídos aos nodes |
| As áreas públicas de rede carregam a marcação de descoberta de serviço externo | sua ausência causa uma falha silenciosa que só aparece no PRD 003 | inspecionar as marcações das áreas de rede |
| A versão do Kubernetes provisionada está dentro do suporte padrão do provedor | fora do suporte padrão o custo por hora do cluster aumenta e as correções de segurança param | consultar a versão do cluster e conferir contra a lista de suporte vigente |
| Nenhum bloco reutilizável referencia origem externa ao repositório | evita colocar código de terceiros no caminho crítico do provisionamento | inspecionar as origens declaradas no código |
| Nenhuma definição de ambiente contém recurso solto — apenas chamadas de capacidade e leituras | é o teste objetivo de que a separação entre definição e valores foi respeitada | inspecionar os arquivos de definição de ambiente |
| O estado do provisionamento e os arquivos locais gerados não estão no controle de versão; o arquivo de versões resolvidas está | o estado contém dados sensíveis em texto claro e o repositório é público | conferir os arquivos rastreados pelo controle de versão |
| A verificação de formatação e a validação do código passam sem apontamentos | erro estrutural detectado antes de criar recurso é ordens de grandeza mais barato | executar as verificações |
| Após a remoção, nenhum componente cobrado permanece ativo | é o requisito que faz o custo parar de verdade | consultar o provedor pelos componentes do ambiente e obter resultado vazio |

### 5b. Métricas de sucesso

| Métrica | Baseline (fonte) | Meta | Prazo | Mín. aceitável | Responsável |
|---|---|---|---|---|---|
| Passos manuais no console necessários para ter o ambiente de pé | A levantar — hoje o ambiente não nasce de código *(premissa — confirme ou corrija)* | 0 | primeira execução completa | 0 | Fabricio |
| Componentes cobrados remanescentes após a remoção | A levantar *(premissa — confirme ou corrija)* | 0 | primeira remoção completa | 0 | Fabricio |
| Tempo entre iniciar a criação e ter o cluster utilizável | A levantar — sem medição registrada *(premissa — confirme ou corrija)* | < 25 minutos | primeira execução completa | < 40 minutos | Fabricio |

## 6. Milestones

### Milestone 1: Ambiente reproduzível a partir do código

**Por que é um marco:** é quando o ambiente deixa de ser um recurso único mantido por uma pessoa e passa a ser algo que qualquer participante recria. Anuncia-se como "o laboratório inteiro está no repositório" — e é o pré-requisito do PRD 003.

**Funcionalidades:** US01, US02

**Checklist de aceite** (marcado pelo Aprovador após a implementação):
- [ ] A criação a partir de clone limpo entrega dois nodes em estado pronto, sem passo manual no console
- [ ] Nenhum node possui endereço alcançável a partir da internet
- [ ] As áreas públicas de rede carregam a marcação de descoberta de serviço externo
- [ ] A versão do Kubernetes está dentro do suporte padrão do provedor
- [ ] Nenhum bloco reutilizável referencia origem externa ao repositório
- [ ] Nenhuma definição de ambiente contém recurso solto
- [ ] O estado e os arquivos locais gerados não estão no controle de versão; o arquivo de versões resolvidas está
- [ ] Formatação e validação passam sem apontamentos

**Aprovador:** Fabricio

### Milestone 2: Ciclo de vida completo com custo controlado

**Por que é um marco:** é o que torna o laboratório sustentável — poder criar e destruir à vontade muda como o material é usado, porque deixa de existir o receio de esquecer algo ligado. Sem ele, cada execução é uma decisão de custo permanente.

**Funcionalidades:** US03

**Checklist de aceite** (marcado pelo Aprovador após a implementação):
- [ ] O procedimento de remoção está documentado com seus pré-requisitos explícitos
- [ ] Após a remoção, nenhum componente cobrado permanece ativo
- [ ] O pré-requisito de remover primeiro o que o cluster criou por conta própria está registrado e foi exercitado ao menos uma vez

**Aprovador:** Fabricio

## 7. Riscos e Dependências

| Risco | Impacto | Mitigação | Status |
|---|---|---|---|
| Perda do estado do provisionamento torna a remoção pelo código impossível, deixando infraestrutura cobrando | Alto — custo contínuo sem forma automatizada de parar | cópia de segurança do estado; tratar a remoção como parte do procedimento e não como limpeza posterior | Pendente |
| O estado local contém dados sensíveis em texto claro e o repositório é público | Alto — exposição de credenciais do cluster | exclusão explícita do estado e dos arquivos locais no controle de versão, feita **antes** da primeira execução | Pendente |
| Componente de exposição criado pelo cluster impede a remoção da rede e continua cobrando | Médio | pré-requisito de remoção declarado em US03 e exercitado ao menos uma vez | Pendente |
| Saída de rede única concentra os limites de consumo de origem externa para o cluster inteiro | Médio — falha ao obter imagens, com sintoma que parece erro de configuração | autenticar no registro de imagens, ou reconhecer o sintoma; ver PRD 001 e PRD 003 | Monitorando |
| Versão do Kubernetes envelhece e sai do suporte padrão, elevando o custo por hora e parando as correções | Médio | versão fixada no código e conferida contra a lista de suporte vigente a cada revisão | Monitorando |
| Um único ponto de saída de rede é ponto único de falha | Baixo — aceitável em laboratório | decisão consciente; múltiplos pontos multiplicariam o custo sem benefício aqui | Mitigado |

**Dependências:**

| Dependência | Tipo | Status | Impacto se bloqueado |
|---|---|---|---|
| Conta de nuvem com permissões para criar rede e cluster | Externa | Disponível | bloqueia os dois milestones |
| Exclusão do estado no controle de versão configurada antes da primeira execução | Interna | Pendente | risco de exposição na primeira execução |
| Decisão de manter o banco dentro do cluster (PRD 003) | Interna | Decidida | se revertida, entra um banco gerenciado no escopo deste PRD |

## 8. Referências

- [EKS — versões em suporte padrão](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html) — define a versão a fixar e o limiar em que o custo por hora do cluster aumenta; consultado em 2026-07-26
- [Amazon EKS — endoflife.date](https://endoflife.date/amazon-eks) — visão consolidada do ciclo de vida das versões
- [Registro de provedores Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest) — origem obrigatória das versões a fixar, consultada no momento da escrita
- [`docs/runbook-deploy-kubernetes.md`](../runbook-deploy-kubernetes.md) — Problema 5 documenta a falha real causada por marcação de rede ausente, e a seção de encerramento documenta a remoção do componente de exposição
- PRD 003 — consome o ambiente criado por este PRD

## 9. Registro de Decisões

- **[2026-07-26]:** Estado do provisionamento mantido localmente. Motivo: há um operador só, e a alternativa exigiria criar antes um repositório de estado compartilhado, o que adiciona um passo sem benefício neste contexto. Consequência registrada como risco de maior severidade deste PRD.
- **[2026-07-26]:** Nodes em rede privada, com saída controlada. Motivo: é a topologia correta; a alternativa mais barata expõe os nodes diretamente. Escolha consciente de pagar mais pela postura adequada.
- **[2026-07-26]:** Um único ponto de saída de rede, e não um por zona. Motivo: um por zona multiplicaria o custo sem benefício em laboratório. Aceito como ponto único de falha.
- **[2026-07-26]:** O provisionamento da infraestrutura não aplica os manifestos da aplicação. Motivo: manter as duas responsabilidades separadas evita acoplar o ciclo de vida da aplicação ao da infraestrutura, e evita a dependência circular de configurar o acesso ao cluster a partir de um cluster que ainda não existe.
- **[2026-07-26]:** Um único ambiente, `dev`. Motivo: não há requisito de homologação ou produção; quando existir, é pasta nova e não variação do mesmo código.
- **[2026-07-26]:** `depends_on` vazio. Motivo: a criação do ambiente não pressupõe comportamento descrito em nenhum outro PRD — o PRD 001 produz um artefato consumido pelo PRD 003, não por este.
