## ADDED Requirements

### Requirement: Imagem publicada atende múltiplas arquiteturas

A imagem publicada SHALL atender `linux/amd64` e `linux/arm64` sob a **mesma** referência de versão, de modo que consumi-la não exija conhecimento nem declaração da arquitetura de destino.

#### Scenario: Manifesto publicado lista as duas arquiteturas

- **WHEN** o manifesto da referência de versão publicada é inspecionado no registro
- **THEN** ele lista `linux/amd64` e `linux/arm64`

#### Scenario: Consumo sem declarar arquitetura

- **WHEN** a imagem é consumida em uma máquina `arm64` e em um nó `amd64`, usando a mesma referência
- **THEN** ambos obtêm a variante correta e executam sem erro de formato de executável

### Requirement: Construção independente por arquitetura

Cada arquitetura SHALL ser construída por inteiro e de forma independente. Nenhum resultado intermediário de construção MUST ser reaproveitado entre arquiteturas.

#### Scenario: Dependências instaladas por arquitetura

- **WHEN** a imagem é construída para as duas arquiteturas
- **THEN** a instalação de dependências ocorre dentro de cada arquitetura, sem copiar o resultado de uma para a outra

#### Scenario: Falha em uma arquitetura impede a publicação

- **WHEN** a construção falha para uma das arquiteturas
- **THEN** nada é publicado, porque publicar apenas uma arquitetura reintroduz a falha que este requisito elimina

### Requirement: Referência de versão imutável

Toda versão publicada SHALL receber uma identificação própria. Uma identificação já publicada MUST NOT ser reescrita com conteúdo diferente, e a identificação `latest` ou qualquer identificação móvel MUST NOT ser usada.

#### Scenario: Nova versão recebe nova identificação

- **WHEN** uma versão nova da aplicação é publicada
- **THEN** ela recebe uma identificação ainda não utilizada, e a anterior permanece intacta no registro

#### Scenario: Identificação móvel é rejeitada

- **WHEN** o procedimento de publicação é inspecionado
- **THEN** ele não usa `latest` nem qualquer identificação cujo conteúdo mude sem que o nome mude

### Requirement: Publicação em registro público sem credencial de consumo

A imagem SHALL ser publicada em `fabricioveronez/kube-news`, com visibilidade pública, de modo que consumi-la não exija autenticação.

#### Scenario: Consumo anônimo funciona

- **WHEN** a imagem é obtida por alguém sem credenciais no registro
- **THEN** a obtenção é bem-sucedida

#### Scenario: Publicação exige autenticação prévia

- **WHEN** a publicação é tentada sem autenticação ativa no registro
- **THEN** a falha é reportada como pré-requisito de autenticação, e não como erro da construção

### Requirement: Diretório de trabalho compatível com os caminhos relativos da aplicação

A imagem SHALL ter como diretório de trabalho aquele em que a aplicação espera estar, porque a aplicação resolve os arquivos estáticos e os modelos de página a partir do diretório de trabalho do processo (`src/server.js`), e não da localização do arquivo de código.

#### Scenario: Recursos estáticos resolvem dentro do container

- **WHEN** a página inicial é requisitada de um container em execução
- **THEN** todos os recursos estáticos respondem com sucesso e com o tipo de conteúdo correto, e nenhum retorna "não encontrado"

#### Scenario: Modelos de página são encontrados

- **WHEN** uma rota que renderiza página é acessada
- **THEN** a página é renderizada sem erro de modelo não encontrado

### Requirement: Conteúdo mínimo e execução sem privilégio administrativo

A imagem SHALL conter apenas o necessário para executar a aplicação e MUST NOT conter segredos, histórico de controle de versão, ou dependências instaladas na máquina de quem publica. O processo SHALL ser executado por usuário sem privilégio administrativo.

#### Scenario: Processo não roda como administrador

- **WHEN** o usuário efetivo do processo em execução é consultado
- **THEN** ele não é o usuário administrativo

#### Scenario: Conteúdo indevido está ausente

- **WHEN** o conteúdo da imagem publicada é inspecionado
- **THEN** não há diretório de controle de versão, arquivos de ambiente com segredos, nem dependências copiadas do sistema de arquivos do host

#### Scenario: Padrão de exclusão cobre subdiretório

- **WHEN** o padrão de exclusão do contexto de construção é inspecionado
- **THEN** ele cobre o diretório de dependências em qualquer profundidade, porque a aplicação vive em um subdiretório do repositório

### Requirement: Verificação de saúde sem dependência adicional na imagem

A imagem SHALL declarar uma verificação de saúde apontando para o endpoint que a aplicação de fato serve, usando capacidade já presente no runtime, sem instalar ferramenta adicional apenas para essa finalidade.

#### Scenario: Verificação usa endpoint existente

- **WHEN** a verificação de saúde da imagem é inspecionada
- **THEN** ela aponta para `/health`, que a aplicação serve, e não para um endpoint inexistente

#### Scenario: Nenhuma ferramenta extra é instalada para a verificação

- **WHEN** a definição da imagem é inspecionada
- **THEN** nenhuma ferramenta de requisição HTTP é instalada com o único propósito de executar a verificação de saúde
