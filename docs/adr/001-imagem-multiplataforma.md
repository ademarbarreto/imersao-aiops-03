# ADR 001 — Imagem multiplataforma com construção independente por arquitetura

- **Data:** 2026-07-26
- **Estado:** Aceita
- **Origem:** decisão D1 da mudança `containerizacao-infra-e-deploy`

## Contexto

A máquina de desenvolvimento é `arm64` (Apple Silicon) e os nós do EKS de destino são `amd64`. Até aqui, a arquitetura correta da imagem dependia de alguém digitar `--platform linux/amd64` a cada build.

Essa dependência já custou tempo real neste projeto. É o Problema 1 do runbook: o build passa, o push passa, o `kubectl apply` passa — e a falha só aparece quando o kernel do nó tenta executar o binário, com `exec format error`. Três passos depois da causa, e num lugar em que ninguém procura por erro de build.

## Decisão

Publicar um índice de imagem cobrindo `linux/amd64` e `linux/arm64` sob a **mesma** referência de versão, construindo cada arquitetura por inteiro e de forma independente.

```
docker buildx build --platform linux/amd64,linux/arm64 --tag <ref> --push .
```

Consumir a imagem deixa de exigir qualquer conhecimento ou declaração da arquitetura de destino.

## Alternativa considerada e descartada

**Instalar as dependências uma única vez, na arquitetura do construtor, e reaproveitar o resultado nas duas variantes.** É mais rápido, e hoje seria seguro: `pg` e `sequelize` são JavaScript puro, sem extensão nativa.

Descartada porque a segurança é circunstancial. No dia em que alguém adicionar uma dependência com extensão nativa, a imagem passa a conter um binário de uma arquitetura só — e a variante errada quebra **em execução no cluster**, não na construção. É exatamente a assinatura de erro que esta decisão existe para eliminar, reintroduzida por uma otimização que ninguém lembraria de revisar.

## Consequências

- A classe de falha de arquitetura é eliminada **por construção**, não prevenida por disciplina. Não há flag para esquecer.
- Se a construção falhar em qualquer arquitetura, nada é publicado — publicar uma arquitetura só reintroduziria o problema.
- A construção fica mais lenta: duas instalações completas de dependências em vez de uma. Custo aceito.
- O runbook e o `CLAUDE.md` ensinavam o procedimento antigo e passaram a ensinar um procedimento obsoleto no momento em que esta decisão foi tomada. Corrigir os dois faz parte da mesma entrega — documento que ensina disciplina desnecessária faz a falha voltar a ser prevenida à mão.
- A tag `v1`, publicada antes desta decisão, continua `amd64` apenas. Ela não é reescrita (ver [ADR 002](002-build-local-e-publicacao-separados.md) sobre imutabilidade de tag); o que aponta para ela segue sujeito ao problema antigo.

## Verificação

`fabricioveronez/kube-news:v1.0.0`, publicada em 2026-07-26:

```
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:0da2d65a3515f6e1344fa80baa8011e22a64106519595268ed1759bb10a3fc2e
  linux/amd64  sha256:10c2999f5931ff7658b80f874564b3dd99ae59c673e57f2d74710cd5ea3ba03c
  linux/arm64  sha256:b79102b090907fae00678b349ebf211bc520930f12432123069cb00aa1230b38
```

Ambas as variantes executadas sob a mesma referência, sem declarar arquitetura: `x86_64` e `aarch64`, as duas com `uid=1000(node)`.
