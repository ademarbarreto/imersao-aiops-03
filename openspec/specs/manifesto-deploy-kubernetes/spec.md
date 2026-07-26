# manifesto-deploy-kubernetes Specification

## Purpose
Definição versionada dos objetos de deploy da aplicação no Kubernetes, com recursos declarados, verificações de saúde, configuração externa ao workload e credencial fora do repositório.

## Requirements

### Requirement: Aplicação do deploy completo em ordem de dependência

O conjunto de objetos do deploy SHALL viver no repositório e ser aplicável de uma vez. A ordem dos documentos MUST respeitar a dependência: o espaço isolado primeiro, a configuração antes das cargas de trabalho, o banco antes da aplicação.

#### Scenario: Aplicação única cria todos os objetos

- **WHEN** o manifesto é aplicado
- **THEN** todos os objetos do deploy são criados, na ordem declarada no arquivo

#### Scenario: Configuração existe antes das cargas

- **WHEN** a ordem dos documentos do manifesto é inspecionada
- **THEN** os objetos de configuração aparecem antes das cargas de trabalho que os consomem

### Requirement: Espaço isolado explícito e identificadores padronizados

Todo objeto SHALL declarar explicitamente o espaço isolado a que pertence, de modo que o destino nunca dependa do contexto de quem executa o comando. Todo objeto SHALL carregar o conjunto padronizado de identificadores recomendado pelo Kubernetes.

#### Scenario: Destino não depende do contexto do operador

- **WHEN** cada objeto do manifesto é inspecionado
- **THEN** todos declaram o espaço isolado explicitamente

#### Scenario: Consulta única traz a aplicação inteira

- **WHEN** os objetos são consultados por um único identificador de instância
- **THEN** a consulta retorna a aplicação inteira, e não apenas parte dela

#### Scenario: Seletor contém apenas o subconjunto imutável

- **WHEN** o seletor da carga de trabalho é inspecionado
- **THEN** ele contém apenas os identificadores de nome e de instância, e não contém o identificador de versão, que muda ao longo da vida do objeto

### Requirement: Recursos declarados em todo container

Todo container executável SHALL declarar reserva e teto de memória e de processamento, incluindo containers auxiliares de inicialização, porque eles disputam o mesmo nó. A reserva de memória MUST ser igual ao teto de memória, porque memória não é recurso compressível.

#### Scenario: Nenhum container sem declaração de recursos

- **WHEN** todos os containers do manifesto são inspecionados
- **THEN** todos declaram reserva e teto de memória e de processamento

#### Scenario: Classe de serviço nunca é a de menor prioridade

- **WHEN** a classe de serviço de cada componente em execução é consultada
- **THEN** nenhuma delas é a classe de menor prioridade, que seria a primeira a ser removida sob pressão de memória do nó

#### Scenario: Container de inicialização também declara recursos

- **WHEN** o container auxiliar de inicialização é inspecionado
- **THEN** ele declara reserva e teto, como qualquer outro

### Requirement: Verificações de saúde com propósitos distintos

O manifesto SHALL declarar verificações de saúde apontando para endpoints **diferentes**, que a aplicação de fato serve. A verificação que decide reiniciar o processo MUST NOT consultar nenhuma dependência externa. Os limiares SHALL ser proporcionais à consequência: a que reinicia é tolerante, a que remove do tráfego é agressiva.

#### Scenario: Endpoints diferentes para propósitos diferentes

- **WHEN** as verificações de saúde do manifesto são inspecionadas
- **THEN** a que decide reiniciar aponta para `/health` e a que decide receber tráfego aponta para `/ready`, ambos servidos pela aplicação

#### Scenario: Queda do banco não reinicia a frota

- **WHEN** o banco fica indisponível por um período
- **THEN** a verificação que decide reiniciar continua passando, porque não consulta o banco, e não há reinício em cascata da frota

#### Scenario: Boot lento é coberto por verificação de inicialização

- **WHEN** a aplicação demora a ficar pronta no start
- **THEN** a cobertura vem de uma verificação de inicialização dedicada, e não de um atraso inicial inflado na verificação que reinicia

### Requirement: Contorno do encerramento por dependência ausente no start

A aplicação termina com código de erro se o banco não responder no start, e verificação de saúde não cobre processo que termina antes de existir o que verificar. O manifesto SHALL segurar o início do container principal com um container auxiliar de inicialização até o banco aceitar conexões.

#### Scenario: Contador de reinícios permanece zero

- **WHEN** o deploy é aplicado do zero e o estado é consultado cinco minutos depois
- **THEN** o contador de reinícios de cada componente é zero

#### Scenario: Container de inicialização obtém endereço da configuração

- **WHEN** o container auxiliar de inicialização é inspecionado
- **THEN** ele obtém o endereço e a porta do banco a partir do objeto de configuração, sem valor literal

### Requirement: Configuração externa ao workload e credencial fora do repositório

Nenhuma variável de ambiente SHALL ser escrita com valor literal na definição da carga de trabalho — todas MUST vir de objeto de configuração ou de segredo. Nenhum valor real de credencial MUST existir no arquivo versionado; o arquivo SHALL carregar um marcador, e o valor entra no momento da aplicação.

#### Scenario: Nenhum valor literal no workload

- **WHEN** a definição das cargas de trabalho é inspecionada
- **THEN** nenhuma variável de ambiente carrega valor literal

#### Scenario: Arquivo versionado contém apenas o marcador

- **WHEN** o arquivo versionado é inspecionado antes de um envio ao repositório
- **THEN** o campo de senha contém apenas o marcador, e nenhum valor real

#### Scenario: Nenhuma variável decorativa

- **WHEN** as variáveis declaradas no objeto de configuração são comparadas com o contrato real da aplicação
- **THEN** todas existem no código, e nenhuma variável é declarada sem que a aplicação a leia

### Requirement: Propagação de mudança de configuração

Alterar o objeto de configuração não reinicia cargas de trabalho por conta própria, e a consulta passa a mostrar o valor novo enquanto a aplicação segue com o antigo, sem erro. O manifesto SHALL declarar um mecanismo explícito que provoque a atualização das cargas afetadas quando a configuração mudar.

#### Scenario: Mudança de configuração provoca atualização

- **WHEN** o bloco de configuração é alterado e o manifesto é reaplicado com o mecanismo de propagação atualizado
- **THEN** as cargas afetadas são atualizadas e passam a usar o valor novo

#### Scenario: Manutenção do mecanismo é parte do procedimento

- **WHEN** o procedimento de edição da configuração é inspecionado
- **THEN** ele exige atualizar o mecanismo de propagação antes de aplicar, sem depender de alguém lembrar de reiniciar manualmente

### Requirement: Referência de imagem imutável

A imagem SHALL ser referenciada por identificação imutável. Identificação móvel MUST NOT ser usada, porque componentes do mesmo deploy passariam a poder executar códigos distintos e a reversão apontaria para o mesmo conteúdo defeituoso.

#### Scenario: Identificação fixa com política de obtenção coerente

- **WHEN** a referência de imagem do manifesto é inspecionada
- **THEN** ela usa identificação imutável, e a política de obtenção é coerente com isso, sem forçar obtenção a cada início

#### Scenario: Versão legível no manifesto

- **WHEN** alguém pergunta qual versão está implantada
- **THEN** a resposta é obtida lendo o manifesto versionado, sem consultar o cluster

### Requirement: Exposição coerente com a intenção

O serviço da aplicação SHALL declarar o tipo que corresponde à exposição pretendida — externa ao cluster. A ligação com a porta da aplicação SHALL ser feita pelo nome da porta, e não pelo número repetido em dois lugares. O seletor MUST corresponder aos identificadores do modelo de pod.

#### Scenario: Lista de destinos não é vazia

- **WHEN** os destinos do serviço são consultados após a aplicação
- **THEN** a lista contém ao menos um endereço por componente pronto, comprovando que o seletor corresponde aos identificadores do pod

#### Scenario: Porta referenciada por nome

- **WHEN** a definição do serviço é inspecionada
- **THEN** o destino da porta é referenciado pelo nome declarado no container

### Requirement: Banco no cluster sem armazenamento persistente

O banco SHALL rodar dentro do cluster sem armazenamento persistente, por decisão de laboratório. Como consequência direta, a estratégia de atualização MUST derrubar a instância antiga antes de subir a nova, para que nunca existam dois bancos com dados divergentes atendendo ao mesmo serviço.

#### Scenario: Atualização não sobrepõe duas instâncias

- **WHEN** a carga de trabalho do banco é atualizada
- **THEN** a instância antiga é encerrada antes de a nova subir

#### Scenario: Perda de dados é comportamento documentado

- **WHEN** o componente do banco é recriado
- **THEN** os dados anteriores não existem mais, e isso está documentado como comportamento esperado, não como incidente
