## ADDED Requirements

### Requirement: Cluster local criado a partir de configuração versionada

O cluster local de validação SHALL ser criado a partir de configuração versionada no repositório, e não de comando digitado de memória. Criar e remover o cluster MUST ser operações rápidas e sem custo, adequadas a um ciclo de correção do manifesto.

#### Scenario: Criação a partir da configuração do repositório

- **WHEN** o comando de criação do cluster local é executado sobre a configuração versionada
- **THEN** o cluster sobe com os nós em estado pronto

#### Scenario: Remoção não deixa custo nem estado

- **WHEN** o cluster local é removido
- **THEN** nenhum recurso permanece, e nenhum dado precisa sobreviver, porque o banco é descartável por decisão de produto

#### Scenario: Recursos insuficientes na máquina

- **WHEN** a máquina não tem recursos suficientes para o cluster e as cargas
- **THEN** a falha é reportada como limitação de recursos, com indicação do mínimo necessário

### Requirement: Paridade de versão com o ambiente de destino

O cluster local SHALL usar a mesma versão de Kubernetes fixada para o ambiente de nuvem. Validar em versão diferente da de destino enfraquece a validação sem economizar nada.

#### Scenario: Versão local igual à de destino

- **WHEN** a versão do cluster local é consultada e comparada com a fixada no provisionamento de nuvem
- **THEN** as versões coincidem na mesma versão menor

### Requirement: Capacidade de exposição externa dada ao ambiente local

O tipo de serviço externo não recebe endereço no cluster local sem uma capacidade adicional. O ambiente local SHALL receber essa capacidade. O manifesto MUST NOT ser alterado para contornar a limitação do ambiente de teste.

#### Scenario: Serviço externo recebe endereço no cluster local

- **WHEN** o manifesto é aplicado no cluster local e o serviço externo é consultado
- **THEN** um endereço externo é atribuído e a aplicação responde por ele

#### Scenario: Troca de tipo de exposição é rejeitada

- **WHEN** o manifesto aplicado localmente é comparado com o manifesto versionado
- **THEN** o tipo de exposição é o mesmo nos dois, sem substituição feita para o teste passar

### Requirement: Manifesto validado é idêntico ao entregue

O manifesto aplicado no cluster local SHALL ser idêntico ao versionado, exceto pela injeção do valor de credencial no momento da aplicação. Qualquer outra divergência produziria validação de um artefato que não é o entregue.

#### Scenario: Comparação não acusa divergência

- **WHEN** o conteúdo efetivamente aplicado é comparado com o arquivo versionado
- **THEN** a única diferença é o valor de credencial substituindo o marcador

### Requirement: Imagem obtida do registro público

A imagem usada na validação SHALL ser a mesma publicada no registro público, obtida de lá — e não uma construção local paralela, que validaria um artefato diferente do que o cluster de nuvem consumirá.

#### Scenario: Imagem vem do registro

- **WHEN** o componente em execução no cluster local é inspecionado
- **THEN** a imagem em uso é a referência publicada no registro público

#### Scenario: Variante de arquitetura local é exercitada

- **WHEN** o cluster local roda em máquina de arquitetura diferente da dos nós de nuvem
- **THEN** a imagem multiplataforma atende a variante local, exercitando justamente a arquitetura que o ambiente de nuvem não exercita

#### Scenario: Falha de obtenção por limite de consumo

- **WHEN** a obtenção da imagem falha
- **THEN** o limite de consumo por origem é verificado antes de a identificação da versão ser investigada, porque o sintoma é indistinguível de erro de referência

### Requirement: Verificação ativa contra as falhas silenciosas conhecidas

Estado "em execução" MUST NOT ser aceito como prova de funcionamento. A verificação SHALL cobrir ativamente cada falha silenciosa conhecida desta camada, porque nenhuma delas gera erro.

#### Scenario: Contador de reinícios é verificado

- **WHEN** o estado dos componentes é consultado cinco minutos após um deploy novo
- **THEN** o contador de reinícios é zero para todos, e valor diferente de zero é tratado como achado, não como ruído

#### Scenario: Lista de destinos é verificada

- **WHEN** os destinos de cada serviço são consultados
- **THEN** nenhuma lista está vazia, porque lista vazia é o sintoma exato de seletor desalinhado e não produz erro em lugar nenhum

#### Scenario: Classe de serviço é verificada

- **WHEN** a classe de serviço de cada componente é consultada
- **THEN** nenhuma é a classe de menor prioridade

#### Scenario: Caminho até o banco é exercitado

- **WHEN** um registro é criado pela API e em seguida consultado diretamente no banco
- **THEN** o registro está presente no banco, comprovando o caminho completo aplicação até banco

#### Scenario: Verificação de saúde do processo não é aceita como prova de conexão

- **WHEN** apenas o endpoint de saúde do processo responde com sucesso
- **THEN** isso não é aceito como prova de que a aplicação conectou ao banco

### Requirement: Tratamento de resultado negativo e limpeza

Quando o resultado de um teste e o conteúdo do banco discordarem, o banco SHALL ser tratado como fonte da verdade. Os dados criados para verificação MUST ser removidos ao final.

#### Scenario: Resultado negativo isolado exige segunda medição

- **WHEN** a ferramenta de teste reporta falha e não há erro correspondente no registro da aplicação
- **THEN** uma segunda medição por outro caminho é feita antes de qualquer investigação, porque a ferramenta de teste também falha

#### Scenario: Dados de verificação são removidos

- **WHEN** a verificação termina
- **THEN** os registros criados para o teste foram removidos, confirmado por contagem antes e depois
