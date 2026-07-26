# ADR 006 — Validação em cluster local, sem adaptar o manifesto

- **Data:** 2026-07-26
- **Estado:** Aceita
- **Origem:** decisão D7 da mudança `containerizacao-infra-e-deploy`

## Contexto

O manifesto precisa ser provado antes de ser entregue. Prová-lo no EKS custa dinheiro por hora — control plane, gateway de saída e balanceador — e coloca o tempo de provisionamento dentro do ciclo de correção: cada ajuste no YAML esperaria minutos de infraestrutura para ser testado.

## Decisão

Provar o manifesto num cluster `kind` local, com **duas restrições que fazem a validação valer alguma coisa**:

1. **Mesma versão menor de Kubernetes do destino.** `kindest/node:v1.36.1` contra `cluster_version = "1.36"` no EKS. Validar em versão diferente enfraquece a validação sem economizar nada.
2. **O manifesto não é adaptado.** O que roda localmente é byte a byte o que é entregue, exceto pela injeção da credencial no lugar do marcador.

A configuração do cluster é versionada em `kind/kind-config.yaml` — não é comando digitado de memória.

## Alternativa considerada e descartada

**Trocar `type: LoadBalancer` por `NodePort` para o teste passar localmente.** É o atalho óbvio, porque um Service do tipo externo não recebe endereço no kind sem capacidade adicional.

Descartada porque produziria a validação de **um artefato que não é o entregue**. A falha reapareceria na nuvem — que é exatamente o que a validação existe para evitar. Quem ganha a capacidade que falta é o **ambiente de teste** (`cloud-provider-kind`), nunca o manifesto.

## Ganho não planejado

Os nós do kind são containers na máquina de desenvolvimento, de arquitetura **`arm64`**. A validação passa a exercitar justamente a variante que o ambiente de nuvem nunca usaria — o que só é possível porque a imagem é multiplataforma ([ADR 001](001-imagem-multiplataforma.md)). Sem ela, este cluster local não conseguiria nem obter a imagem.

## O que esta validação prova, e o que não prova

**Prova** — verificado em 2026-07-26, cluster `kind` v0.32.0, nós `v1.36.1`:

- ordem de aplicação e criação dos 7 objetos
- `RESTARTS: 0` em todos os pods seis minutos após um deploy limpo — o `initContainer` segura o start
- nenhum pod em `BestEffort`
- `EndpointSlice` não vazio em cada Service — seletor alinhado
- caminho completo aplicação → Service → banco, confirmado com `psql` dentro do pod do banco
- **separação de probes**: com o pod do banco removido, os pods da aplicação não reiniciaram e o `creationTimestamp` não mudou
- propagação de mudança de configuração: alterar o bloco de config e recalcular o hash provocou rollout dos dois Deployments

**Não prova:**

- atribuição de `EXTERNAL-IP` — `cloud-provider-kind` exige `sudo`, que não estava disponível na execução. `<pending>` até hoje. Obtida evidência parcial pelo `nodePort` do próprio Service (`HTTP 200`, página renderizada), o que cobre seletor e caminho de rede, mas não a atribuição de endereço.
- eficácia da marcação de descoberta nas subnets, que só se prova com balanceador real
- arquitetura `amd64` dos nós, que o ambiente local não tem
- a janela de aproximadamente 170 segundos até a primeira resposta do balanceador, registrada no runbook

## Consequências

- O ciclo criar / aplicar / verificar / remover roda em poucos minutos, sem conta em nuvem e sem custo — quem acompanha o material exercita tudo na própria máquina.
- **Nada foi validado na nuvem nesta rodada, nem a infraestrutura nem o manifesto.** A lacuna é declarada, não coberta. A saída é uma mudança futura de provisionamento e deploy em nuvem, executada quando houver decisão de gastar — ela consome este manifesto e o código Terraform, ambos já provados no que era possível provar sem custo.
