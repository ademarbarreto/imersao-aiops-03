# ADR 003 — Estado do provisionamento local, e não remoto

- **Data:** 2026-07-26
- **Estado:** Aceita, com risco assumido
- **Origem:** decisão D4 da mudança `containerizacao-infra-e-deploy`

## Contexto

O Terraform precisa guardar o estado do que provisionou em algum lugar. A opção canônica em time é um repositório remoto compartilhado, com travamento. Aqui há **um operador só**, e criar antes um repositório de estado compartilhado seria um passo de infraestrutura extra sem benefício correspondente.

## Decisão

Estado local, na máquina de quem executa, declarado explicitamente:

```hcl
backend "local" {
  path = "terraform.tfstate"
}
```

## Risco assumido, e a contrapartida que ele torna obrigatória

O estado do Terraform **carrega dados sensíveis do cluster em texto claro**, e este repositório é **público**.

A consequência prática é que a exclusão do estado no controle de versão **não é higiene — é a única mitigação existente**, e ela precisa estar configurada **antes da primeira inicialização**. Um `terraform init` já cria `.terraform/`; um `git add .` distraído depois disso publica o que não deveria sair da máquina. É o único risco desta decisão que causa dano **antes de qualquer recurso existir**.

Por isso a exclusão foi o primeiro passo da implementação, e não o último. Padrões cobertos em `.gitignore`:

```
*.tfstate   *.tfstate.*   .terraform/   *.tfvars   tfplan   *.tfplan   crash.log
!.terraform.lock.hcl      !*.tfvars.example
```

Verificado com `git check-ignore` antes de qualquer `terraform init`, e novamente depois do `plan`.

## Segundo risco, de natureza diferente

**Perder o estado remove a capacidade de destruir pelo código.** Sem estado, o Terraform não sabe o que criou, e os componentes provisionados continuam existindo — e cobrando — sem nada que os remova automaticamente. Num backend remoto isso é mitigado por durabilidade e versionamento do bucket; num arquivo local, a mitigação é cópia de segurança manual.

## Consequências

- Não há travamento de estado. Com um operador só, não há concorrência a proteger; com dois, esta decisão precisa ser revista antes de qualquer outra coisa.
- A remoção do ambiente precisa ser tratada como parte do procedimento, e não como limpeza posterior — ver [ADR 004](004-provisionamento-nao-aplica-manifestos.md) sobre o pré-requisito de remoção.
- `terraform.tfvars` fica fora do controle de versão junto com o resto, e o ambiente passa a depender de `terraform.tfvars.example` para ser reproduzível a partir de um clone limpo. Nenhum valor sensível vive nele — região, CIDRs, tipo de instância e contagem —, então versioná-lo diretamente é uma alternativa defensável, e é decisão do responsável.

## Quando revisar

Ao entrar um segundo operador, ou ao primeiro `terraform apply` real. Estado local com um operador é uma escolha; com dois, é um incidente esperando data.
