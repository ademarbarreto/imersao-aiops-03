# Grupo 5 — Imagem multiplataforma publicada (executado em 2026-07-26)

| # | Comando | Saída obtida | Veredito |
|---|---|---|---|
| 5.1 | `docker buildx create --name kube-news-multiarch --driver docker-container --bootstrap` | builder `kube-news-multiarch`, buildkit v0.31.2, plataformas incluindo `linux/amd64` e `linux/arm64` | PASSOU |
| 5.2 | `docker buildx build --platform linux/amd64,linux/arm64` | estágios `[linux/amd64 deps]` e `[linux/arm64 deps]` instanciados separadamente — `npm ci` roda dentro de cada arquitetura | PASSOU |
| 5.3 | `docker login` + `--push` para `fabricioveronez/kube-news:v1.0.0` | `Login Succeeded`; `pushing manifest ... DONE 14.7s` | PASSOU |
| 5.4 | `docker buildx imagetools inspect` | `MediaType: application/vnd.oci.image.index.v1+json` com **duas** entradas: `linux/amd64` e `linux/arm64` | PASSOU |
| 5.5 | Token anônimo em `auth.docker.io` + `GET /manifests/v1.0.0` | `manifest HTTP 200` sem credencial | PASSOU |
| 5.6 | `docker run --entrypoint sh` sobre a imagem publicada | `/app` contém só `server.js`, `middleware.js`, `system-life.js`, `models/`, `static/`, `views/`, `package*.json`, `node_modules`. Ausentes: `.git`, `.env`, `docs`, `openspec`, `terraform`, `k8s`, `CLAUDE.md`. Busca por `.env*`/`*.pem`/`*credential*` → vazia. `uid=1000(node)` | PASSOU |
| 5.7 | Registro de versão e digest | abaixo | PASSOU |

## Identificação publicada

```
Referência:      fabricioveronez/kube-news:v1.0.0
Índice (digest): sha256:0da2d65a3515f6e1344fa80baa8011e22a64106519595268ed1759bb10a3fc2e
  linux/amd64:   sha256:10c2999f5931ff7658b80f874564b3dd99ae59c673e57f2d74710cd5ea3ba03c
  linux/arm64:   sha256:b79102b090907fae00678b349ebf211bc520930f12432123069cb00aa1230b38
Node na imagem:  v24.18.0
```

Execução das duas variantes sob a **mesma** referência, sem declarar arquitetura em lugar nenhum:

| Plataforma | `uname -m` | `id` |
|---|---|---|
| `linux/amd64` | `x86_64` | `uid=1000(node)` |
| `linux/arm64` | `aarch64` | `uid=1000(node)` |

## Achado

### A-4 — A tag `v1` preexistente é amd64-only

O repositório já continha `fabricioveronez/kube-news:v1`, publicada em 2026-07-25, com `archs=amd64` apenas — exatamente a classe de falha que esta mudança elimina. Ela **não foi tocada**: a publicação de `v1.0.0` é aditiva, e o requisito de referência imutável proíbe reescrever identificação já publicada.

**Pendência para o responsável, não corrigida aqui:** qualquer manifesto ou documento que ainda aponte para `:v1` continua sujeito ao `exec format error` em nó `arm64`. O manifesto entregue nesta mudança aponta para `:v1.0.0`.
