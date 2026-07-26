# ADR 002 — Caminho de construção local separado do de publicação

- **Data:** 2026-07-26
- **Estado:** Aceita
- **Origem:** decisão D2 da mudança `containerizacao-infra-e-deploy`

## Contexto

A [ADR 001](001-imagem-multiplataforma.md) exige um índice multiplataforma publicado no registro. O ambiente local, por sua vez, precisa subir a partir de um clone limpo com **um comando**, sem passo extra e sem conta em registro nenhum.

Duas restrições técnicas impedem que os dois caminhos sejam o mesmo:

1. O armazenamento local de imagens do Docker **não guarda índice multiplataforma**. Um build multiplataforma não tem onde aterrissar localmente — a saída precisa ir para o registro.
2. O construtor padrão do Docker **não atende múltiplas arquiteturas**. É preciso um construtor dedicado, criado explicitamente.

## Decisão

Manter dois caminhos distintos:

| Caminho | Como | Identificação |
|---|---|---|
| **Ambiente local** | `docker compose build` — nativo, arquitetura da máquina | `kube-news:local` |
| **Publicação** | `docker buildx build --platform … --push` — construtor dedicado, direto ao registro | `fabricioveronez/kube-news:v1.0.0` |

As identificações são deliberadamente distintas.

## Alternativa considerada e descartada

**Unificar os dois caminhos**, fazendo o ambiente local consumir a mesma imagem publicada. Descartada porque quebraria a promessa de subida em um comando: exigiria que a imagem já estivesse publicada antes de qualquer `docker compose up`, e portanto exigiria credencial de registro e conectividade para levantar o ambiente local — precisamente o que o requisito de zero-config elimina.

## Consequências

- **Dois caminhos para manter.** É o custo aceito, e ele é real: uma mudança no `Dockerfile` precisa ser exercitada nos dois.
- A identificação local distinta **impede que a construção local sobrescreva a imagem publicada** no cache da máquina. Sem isso, um `docker compose build` deixaria no cache uma imagem de arquitetura única com o nome da publicada, e um teste posterior validaria o artefato errado.
- Toda versão publicada recebe identificação própria, e **identificação já publicada nunca é reescrita**. `latest` — ou qualquer identificação cujo conteúdo mude sem que o nome mude — não é usada: com ela, componentes do mesmo deploy poderiam executar códigos distintos, e uma reversão apontaria para o mesmo conteúdo defeituoso.
- A validação em cluster local consome a imagem **do registro** (ver [ADR 006](006-validacao-em-cluster-local.md)), e não a construção local — validar a construção local seria validar um artefato diferente do que o cluster de nuvem consumirá.
