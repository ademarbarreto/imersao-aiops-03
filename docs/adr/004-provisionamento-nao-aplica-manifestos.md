# ADR 004 — O provisionamento de infraestrutura não aplica os manifestos

- **Data:** 2026-07-26
- **Estado:** Aceita
- **Origem:** decisão D3 da mudança `containerizacao-infra-e-deploy`

## Contexto

O Terraform tem providers de Kubernetes e de Helm, e é tentador criar o cluster e aplicar os manifestos no mesmo `apply` — um comando, um estado, uma coisa só.

O problema é de ordem de resolução, não de gosto. Um provider de Kubernetes precisa ser configurado com o endpoint e o certificado do cluster. Se esses atributos vêm de um recurso que o **mesmo** estado ainda vai criar, a configuração do provider precede o conhecimento do valor, e o primeiro planejamento não resolve.

O sintoma é o clássico "rode `terraform apply` duas vezes" — e ele não é um contratempo pontual: **reaparece em toda remoção**, quando o cluster deixa de existir enquanto o provider ainda precisa estar configurado para remover o que vive dentro dele.

## Decisão

Duas camadas, duas ferramentas, dois momentos:

| Camada | Ferramenta | Artefato |
|---|---|---|
| Cluster e rede | Terraform | `terraform/` |
| Objetos da aplicação | `kubectl` | `k8s/kube-news.yaml` |

Nenhum provider de Kubernetes ou Helm é declarado no projeto Terraform.

## Acoplamento residual

A separação não é total, e o ponto de contato precisa estar declarado: **a marcação de descoberta nas subnets públicas** (`kubernetes.io/role/elb`) é criada pelo provisionamento, e sem ela a exposição do Service do tipo externo **nunca completa**.

Esse é o Problema 5 do runbook, e a falha silenciosa mais provável no primeiro provisionamento real. Ela não gera erro em lugar nenhum: o `terraform apply` termina com sucesso, o `kubectl apply` termina com sucesso, e o `EXTERNAL-IP` fica `<pending>` para sempre, numa camada que não é a que causou o problema.

## Consequência para a remoção

O balanceador criado pelo controlador do cluster **não está no estado do Terraform**. Destruir na ordem inversa trava a remoção da rede por interface de rede pendente, e deixa o balanceador cobrando indefinidamente.

Por isso a remoção tem um pré-requisito explícito, e ele é parte do procedimento e não uma limpeza posterior:

```bash
kubectl delete svc kube-news -n kube-news   # ANTES
terraform destroy                           # DEPOIS
```

## Estado atual

**Documentado, não exercitado.** `terraform apply` e `terraform destroy` não foram executados nesta rodada (ver [ADR 006](006-validacao-em-cluster-local.md) e a decisão de custo zero). O procedimento de remoção acima permanece **não verificado**.
