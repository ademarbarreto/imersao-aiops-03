# infraestrutura-eks Specification

## Purpose
Provisionamento e remoção do cluster EKS e da rede a partir de código versionado, com estado local e separação entre definição de capacidade e valores de ambiente.

## Requirements

### Requirement: Criação do ambiente a partir de código versionado

O ambiente SHALL ser criado integralmente a partir do código do repositório, sem nenhum passo manual no console da nuvem.

#### Scenario: Criação a partir de clone limpo

- **WHEN** a criação é executada a partir de um clone limpo do repositório
- **THEN** o cluster fica utilizável e a listagem de nós retorna dois nós em estado pronto

#### Scenario: Execução interrompida é retomável

- **WHEN** a criação é interrompida no meio, por quota atingida ou por qualquer outra falha
- **THEN** o que já foi criado permanece registrado no estado, e uma nova execução continua de onde parou em vez de recomeçar

### Requirement: Separação entre definição de capacidade e valores de ambiente

O código SHALL separar a definição de *como* cada capacidade de infraestrutura é construída dos *valores* que cada ambiente usa. A definição de um ambiente MUST conter apenas chamadas de capacidade e, quando necessário, leituras de recursos preexistentes — nunca declarações de recurso soltas.

#### Scenario: Nenhum recurso solto na definição de ambiente

- **WHEN** os arquivos de definição do ambiente são inspecionados
- **THEN** eles contêm apenas chamadas de capacidade e leituras, e nenhuma declaração de recurso

#### Scenario: Ambiente é uma pasta com estado próprio

- **WHEN** a estrutura do projeto é inspecionada
- **THEN** cada ambiente é uma pasta com seus próprios valores e seu próprio estado, e não há uso de mecanismo de alternância de estado sobre o mesmo código

#### Scenario: Capacidade não fixa configuração de destino

- **WHEN** a definição de uma capacidade é inspecionada
- **THEN** ela declara de quais provedores precisa, mas não configura onde provisionar — essa configuração vive na definição do ambiente

### Requirement: Versões fixadas a partir de consulta à origem

Todas as versões de ferramenta e de provedor SHALL ser fixadas explicitamente, com o valor obtido por consulta à origem no momento da escrita. Versões MUST NOT ser reproduzidas de memória.

#### Scenario: Versões declaradas explicitamente

- **WHEN** os arquivos de versão são inspecionados
- **THEN** a versão da ferramenta e a de cada provedor estão declaradas, sem deixar a resolução livre

#### Scenario: Arquivo de versões resolvidas é versionado

- **WHEN** os arquivos rastreados pelo controle de versão são conferidos
- **THEN** o arquivo que fixa as versões efetivamente resolvidas está presente, garantindo o mesmo provedor em máquinas diferentes

### Requirement: Nenhuma dependência de código de terceiros no provisionamento

Toda capacidade reutilizável SHALL ser escrita e mantida no próprio repositório. Nenhuma referência MUST apontar para registro público de terceiros.

#### Scenario: Origens são internas ao repositório

- **WHEN** as origens declaradas no código são inspecionadas
- **THEN** todas apontam para caminho local do repositório, e nenhuma para registro público de terceiros

### Requirement: Topologia de rede com nós isolados da internet

A rede SHALL conter áreas públicas e privadas distribuídas em pelo menos duas zonas de disponibilidade, atendendo ao mínimo exigido pelo serviço de cluster. Os nós SHALL ficar nas áreas privadas e alcançar a internet por uma saída controlada. Nenhum nó MUST ser diretamente alcançável a partir da internet.

#### Scenario: Nós sem endereço público

- **WHEN** os endereços atribuídos aos nós são inspecionados
- **THEN** nenhum nó possui endereço alcançável a partir da internet

#### Scenario: Nós alcançam o registro de imagens

- **WHEN** um nó precisa obter a imagem da aplicação de um registro público
- **THEN** a obtenção é bem-sucedida através da saída controlada da rede privada

#### Scenario: Distribuição mínima em zonas

- **WHEN** a rede é inspecionada
- **THEN** existem áreas em pelo menos duas zonas de disponibilidade

### Requirement: Marcação de descoberta para exposição de serviço

As áreas de rede SHALL carregar a marcação que o cluster usa para descobrir onde publicar um serviço externo. Sua ausência causa falha silenciosa que se manifesta apenas na camada de deploy.

#### Scenario: Áreas públicas marcadas para exposição externa

- **WHEN** as marcações das áreas públicas de rede são inspecionadas
- **THEN** elas carregam a marcação de descoberta de serviço externo

#### Scenario: Exposição do serviço completa sem intervenção

- **WHEN** um serviço do tipo externo é criado no cluster
- **THEN** o endereço externo é atribuído sem que nenhuma marcação precise ser adicionada manualmente depois

### Requirement: Versão de Kubernetes dentro do suporte padrão

A versão de Kubernetes provisionada SHALL estar dentro do suporte padrão do provedor de nuvem no momento da escrita, e a escolha MUST prevalecer sobre valores herdados de exemplos externos.

#### Scenario: Versão dentro do suporte padrão

- **WHEN** a versão do cluster é consultada e comparada com a lista de suporte vigente do provedor
- **THEN** ela está dentro do suporte padrão, e não em suporte estendido nem fora de suporte

### Requirement: Estado do provisionamento fora do controle de versão

O estado do provisionamento e os arquivos locais gerados MUST NOT entrar no controle de versão, porque o estado contém dados sensíveis em texto claro e o repositório é público. A exclusão SHALL estar configurada **antes** da primeira execução.

#### Scenario: Estado não é rastreado

- **WHEN** os arquivos rastreados pelo controle de versão são conferidos após uma execução
- **THEN** nenhum arquivo de estado e nenhum diretório local gerado está presente

#### Scenario: Exclusão configurada antes da primeira execução

- **WHEN** o repositório é preparado para a primeira execução
- **THEN** os padrões de exclusão já cobrem estado e arquivos locais, antes que qualquer estado exista

### Requirement: Remoção completa do ambiente com pré-requisito explícito

A remoção do ambiente SHALL ser procedimento documentado de primeira classe. Componentes criados por dentro do cluster, e não pelo provisionamento, MUST ser removidos antes, porque não estão registrados no estado e impedem a remoção da rede.

#### Scenario: Remoção completa zera os componentes cobrados

- **WHEN** a remoção é executada após o pré-requisito ser cumprido
- **THEN** a consulta ao provedor pelos componentes do ambiente retorna resultado vazio

#### Scenario: Remoção sem o pré-requisito trava

- **WHEN** a remoção é executada sem remover antes o componente de exposição criado pelo cluster
- **THEN** a remoção da rede trava por dependência pendente, e o componente permanece cobrando — motivo pelo qual o pré-requisito existe

#### Scenario: Remoção interrompida é retomável

- **WHEN** a remoção é interrompida no meio
- **THEN** executá-la novamente conclui o que faltou, a partir do estado

### Requirement: Verificação estrutural antes do provisionamento

A verificação de formatação e a validação do código SHALL passar sem apontamentos antes de qualquer recurso ser criado.

#### Scenario: Formatação e validação passam

- **WHEN** as verificações de formatação e validação são executadas sobre o projeto
- **THEN** ambas concluem sem apontamentos
