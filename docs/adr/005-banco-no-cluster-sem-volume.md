# ADR 005 — Banco no cluster, sem armazenamento persistente

- **Data:** 2026-07-26
- **Estado:** Aceita — decisão de laboratório
- **Origem:** decisão D6 da mudança `containerizacao-infra-e-deploy`

## Contexto

O `kube-news` precisa de um PostgreSQL. As opções eram banco gerenciado provisionado pela camada de infraestrutura, banco no cluster com volume persistente, ou banco no cluster sem volume nenhum.

Os dados desta aplicação são descartáveis — é um portal de notícias de demonstração —, e o contraste entre "com volume" e "sem volume" é conteúdo didático da imersão.

## Decisão

PostgreSQL rodando no cluster, **sem `PersistentVolumeClaim`**. Os dados vivem na camada gravável do container.

## Alternativa considerada e descartada

**Banco gerenciado provisionado pelo Terraform.** Eliminaria de uma vez os Problemas 3 e 4 do runbook, e o custo de implementá-la caiu bastante agora que existe infraestrutura como código. Descartada para manter o conteúdo didático e o custo baixos — um banco gerenciado cobra por hora enquanto ligado.

## Consequência que precisa de tratamento explícito no manifesto

A estratégia de atualização do Deployment **precisa** derrubar a instância antiga antes de subir a nova:

```yaml
strategy:
  type: Recreate
```

Com atualização gradual, existiriam dois bancos com **dados divergentes** atendendo ao mesmo Service enquanto o rollout durasse. Não é uma degradação de disponibilidade — é corrupção observável, com requisições consecutivas vendo estados diferentes.

## Consequência não prevista, descoberta na validação

Recriar o pod do banco apaga a tabela `Posts`. Isso é esperado. O que não estava previsto é o que acontece **em seguida**:

1. Os pods da aplicação **não** reiniciam por causa disso — a probe que reinicia consulta `/health`, que não toca no banco. A separação de probes se sustenta, como projetado.
2. Mas a primeira requisição a `GET /` depois disso executa `Post.findAll()`, que falha com `relation "Posts" does not exist`.
3. A rota é `async` e **não tem `catch`** (`src/server.js:74-78`). A rejeição não tratada **termina o processo**.
4. O container reinicia, o boot roda `sync({alter:true})`, a tabela é recriada, e a aplicação volta.

É a mesma classe de defeito do encerramento por dependência ausente no boot, mas **em tempo de requisição** — e por isso nenhum contorno de ordenação de start a cobre. `initContainer` e `depends_on` resolvem o boot; não resolvem isto.

O defeito está em `src/`, fora do escopo da mudança que produziu este ADR, e **não foi corrigido**. Ele está registrado aqui porque é consequência direta desta decisão: sem volume, a recriação do pod do banco é rotina, e cada uma delas derruba um pod da aplicação.

## Consequências

- **Perda de dados na recriação do pod é comportamento documentado, não incidente.** Restart, rollout e reagendamento do pod apagam tudo.
- Não use esta configuração com dado que importa.
- No ambiente local em Docker Compose a decisão é a **oposta**: lá existe volume nomeado, e a persistência entre ciclos é requisito verificado. As duas decisões coexistem de propósito — o contraste é o conteúdo.
