# ambiente-local-docker Specification

## Purpose
Subida da aplicação e do banco em um comando, zero-config, com ordem de inicialização amarrada à prontidão real do banco e persistência entre ciclos.

## Requirements

### Requirement: Subida da stack completa em um único comando

O sistema SHALL permitir subir a aplicação e o banco de dados a partir de um clone limpo do repositório com um único comando, sem que o usuário instale Node ou PostgreSQL e sem que crie qualquer arquivo de configuração.

#### Scenario: Clone limpo sobe sem configuração manual

- **WHEN** o usuário clona o repositório e executa o comando de subida, sem criar nenhum arquivo `.env`
- **THEN** a aplicação e o banco sobem, e a página inicial responde `HTTP 200` a partir do host

#### Scenario: Nenhum arquivo de configuração é exigido

- **WHEN** o repositório é inspecionado após um clone limpo
- **THEN** não existe nenhum arquivo de configuração pendente de preenchimento que o caminho feliz exija

### Requirement: Espelhamento dos valores padrão da aplicação

O ambiente local SHALL usar exatamente os valores padrão que o código da aplicação já assume (`src/models/post.js`). O único valor alterado MUST ser o endereço do banco, que deixa de ser `localhost` e passa a ser o nome do serviço na rede do ambiente.

#### Scenario: Credenciais do banco batem com o padrão do código

- **WHEN** o serviço de banco é inicializado pelo ambiente local
- **THEN** ele cria exatamente o banco, o usuário e a senha que a aplicação assume por padrão, e a aplicação conecta sem configuração adicional

#### Scenario: Valor com caractere especial é preservado

- **WHEN** um valor padrão contém um caractere que o formato de configuração interpreta de modo especial, como `#`
- **THEN** o valor é escapado corretamente e chega íntegro ao banco e à aplicação

### Requirement: Ordenação da inicialização pela prontidão real do banco

A aplicação SHALL ser iniciada somente após o banco confirmar que aceita conexões, verificado pelo próprio banco e não por tempo de espera fixo. A verificação MUST considerar o banco e o usuário que a aplicação realmente usa, não o padrão genérico do serviço.

#### Scenario: Aplicação aguarda o banco em vez de terminar

- **WHEN** o ambiente é iniciado e o banco ainda não aceita conexões
- **THEN** a aplicação não é iniciada, aguarda, e o contador de reinícios do container permanece zero após 30 segundos de execução

#### Scenario: Verificação de prontidão usa o banco e o usuário da aplicação

- **WHEN** a verificação de prontidão do banco é executada
- **THEN** ela consulta o banco e o usuário específicos da aplicação, e não retorna sucesso antes de o banco da aplicação existir

### Requirement: Persistência dos dados entre ciclos do ambiente

O banco SHALL preservar os dados entre parada e nova subida do ambiente local, usando armazenamento nomeado.

#### Scenario: Registro sobrevive a parar e subir

- **WHEN** um registro é criado pela API, o ambiente é parado e subido novamente sem remover volumes
- **THEN** o registro continua presente ao ser consultado

#### Scenario: Reinício do processo não é aceito como prova de persistência

- **WHEN** a persistência é verificada
- **THEN** a verificação recria o container, e não apenas reinicia o processo no mesmo sistema de arquivos

### Requirement: Alcançabilidade a partir do host

A aplicação SHALL ser alcançável a partir da máquina do usuário, não apenas de dentro do ambiente. O banco SHALL ter sua porta publicada apenas no endereço de loopback.

#### Scenario: Aplicação responde do host

- **WHEN** uma requisição é feita da máquina do usuário para a porta publicada da aplicação
- **THEN** a aplicação responde, comprovando que o processo escuta em endereço alcançável de fora do container

#### Scenario: Recursos estáticos respondem com o tipo correto

- **WHEN** cada recurso estático referenciado pela página inicial é requisitado a partir do host
- **THEN** todos respondem com sucesso **e** com o tipo de conteúdo coerente com sua extensão

#### Scenario: Porta do banco não é exposta na rede local

- **WHEN** a configuração de publicação de portas é inspecionada
- **THEN** a porta do banco está publicada apenas em `127.0.0.1`

### Requirement: Encerramento limpo do processo

O container da aplicação SHALL encaminhar o sinal de término ao processo, de modo que a parada do ambiente conclua sem depender do tempo limite de encerramento forçado.

#### Scenario: Parada retorna antes do tempo limite

- **WHEN** o ambiente é parado
- **THEN** a operação retorna em menos de 10 segundos, indicando que o sinal de término chegou ao processo

### Requirement: Tratamento de conflitos com recursos existentes

O ambiente local SHALL reportar conflitos com recursos já existentes na máquina antes de remover qualquer coisa, e MUST NOT remover dados sem confirmação explícita do usuário.

#### Scenario: Porta do host já ocupada

- **WHEN** a porta que a aplicação usaria já está ocupada na máquina
- **THEN** a subida falha indicando o conflito de porta, e é possível publicar em outra porta sem editar arquivos do repositório

#### Scenario: Volume ou container homônimo de outro projeto

- **WHEN** existe um recurso conflitante na máquina que pode pertencer a outro projeto
- **THEN** o conflito é reportado com a origem identificada, e nenhum volume de dados é removido sem confirmação
