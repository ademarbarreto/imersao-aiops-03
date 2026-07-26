# Grupos 9 e 10 — Infraestrutura EKS como código e validação estática (2026-07-26)

> **`terraform apply` e `terraform destroy` NÃO foram executados.** Nenhum recurso
> existe na nuvem e nada foi cobrado. Tudo abaixo é validação estática e leitura.

## 9.1 — Versões consultadas na origem nesta sessão

| Item | Valor | Origem | Consultado em |
|---|---|---|---|
| Provider AWS | **6.56.0** (publicado 2026-07-22) | `registry.terraform.io/v1/providers/hashicorp/aws` | 2026-07-26 |
| Terraform CLI | **1.15.8** (2026-07-08) | `api.releases.hashicorp.com/v1/releases/terraform/latest` | 2026-07-26 |
| Terraform local | 1.15.6 (`darwin_arm64`) | `terraform version` | 2026-07-26 |
| EKS | **1.36** | suporte padrão vigente (design.md, D9) | 2026-07-26 |

Fixado como `version = "~> 6.56"` e `required_version = ">= 1.15"`. Nenhuma versão veio de memória.

## Estrutura entregue

```
terraform/
├── modules/
│   ├── network/   { main.tf, variables.tf, outputs.tf, versions.tf }
│   └── eks/       { main.tf, variables.tf, outputs.tf, versions.tf }
└── environments/
    └── dev/       { main.tf, variables.tf, outputs.tf, versions.tf,
                     providers.tf, terraform.tfvars.example, .terraform.lock.hcl }
```

## Grupo 10 — Validação estática

| # | Comando | Saída obtida | Veredito |
|---|---|---|---|
| 10.1 | `terraform fmt -recursive -check -diff` | sem apontamentos | PASSOU |
| 10.2 | `terraform init -backend=false` nos 2 módulos e no ambiente | os três concluíram | PASSOU |
| 10.3 | `terraform validate` nos 2 módulos e no ambiente | `Success! The configuration is valid.` nos três | PASSOU |
| 10.4 | `terraform plan -out=tfplan` | plano gerado; **`apply` não executado** | PASSOU |
| 10.5 | `terraform show -json tfplan`, revisão recurso a recurso | 23 recursos, revisão abaixo, 0 falhas | PASSOU (com ressalva) |
| 10.6 | `grep -rE 'source\s*='` | só `../../modules/network`, `../../modules/eks` e `hashicorp/aws` | PASSOU — nenhum registro de terceiros |
| 10.7 | `grep -rE '^\s*resource\s' terraform/environments/` | vazio | PASSOU |
| 10.8 | `grep -rE 'terraform\.workspace\|configuration_aliases\|^\s*provider\s' terraform/modules/` | vazio | PASSOU |
| 10.9 | `git check-ignore` + `git add -An` | ver abaixo | PASSOU — após corrigir A-9 |

### 10.5 — Revisão do plano

23 recursos a criar:

| Qtd | Tipo |
|---|---|
| 1 | `aws_vpc` |
| 4 | `aws_subnet` (2 públicas, 2 privadas) |
| 1 | `aws_internet_gateway` |
| 1 | `aws_eip` |
| 1 | `aws_nat_gateway` |
| 3 | `aws_route_table` |
| 4 | `aws_route_table_association` |
| 2 | `aws_iam_role` |
| 4 | `aws_iam_role_policy_attachment` |
| 1 | `aws_eks_cluster` |
| 1 | `aws_eks_node_group` |

Conferido no plano, item a item:

```
OK  nenhuma subnet privada atribui IP público (map_public_ip_on_launch = false)
OK  tag kubernetes.io/role/elb=1           em kube-news-dev-public-us-east-1a
OK  tag kubernetes.io/role/elb=1           em kube-news-dev-public-us-east-1b
OK  tag kubernetes.io/role/internal-elb=1  em kube-news-dev-private-us-east-1a
OK  tag kubernetes.io/role/internal-elb=1  em kube-news-dev-private-us-east-1b
OK  versão do cluster = 1.36
OK  endpoint privado habilitado
OK  desired_size = 2   (min=2, max=3)
OK  zonas de disponibilidade: ['us-east-1a', 'us-east-1b']
OK  saída controlada única (1 NAT gateway)
```

**Ressalva sobre "nenhum nó com endereço público".** O plano traz `subnet_ids` do
`aws_eks_node_group` como *known after apply*, então o plano **não prova** que os nós
caem nas subnets privadas. O que se pode afirmar é mais fraco e precisa ser dito assim:
o código liga `node_subnet_ids = module.network.private_subnet_ids`
(`terraform/environments/dev/main.tf`) e as privadas têm `map_public_ip_on_launch = false`.
A prova de fato só existe depois de um `apply`, que não aconteceu.

### 10.9 — Nada de estado rastreável

```
terraform/environments/dev/.terraform                IGNORADO
terraform/environments/dev/tfplan                    IGNORADO
terraform/environments/dev/terraform.tfstate         IGNORADO
terraform/environments/dev/terraform.tfvars          IGNORADO
terraform/environments/dev/.terraform.lock.hcl       RASTREÁVEL   ← correto, deve ser versionado
terraform/environments/dev/terraform.tfvars.example  RASTREÁVEL   ← correto
```

`git add -An terraform/` lista **apenas** arquivos `.tf`, o `.terraform.lock.hcl` do ambiente
e o `.tfvars.example`. O `plan` não criou nenhum `terraform.tfstate`.

## 10.10 — Checklist "Antes de entregar" da skill `terraform-boas-praticas`

- [x] Nenhum `resource` no root de um ambiente — só `module` e um `data "aws_caller_identity"` (leitura, permitida)
- [x] Todo módulo tem `variables.tf` com `type` + `description` em cada variável, e `outputs.tf` com o que o consumidor precisa
- [x] Nenhum bloco `provider` dentro de módulo — só `required_providers`
- [x] Um diretório por ambiente, com `backend` (local, por D4) e valores próprios
- [x] Nenhuma referência a `terraform.workspace`, nenhum comando `terraform workspace`
- [x] Todo `source` aponta para caminho local — nenhum do registro público
- [x] A versão em cada `required_providers` veio de consulta ao registro nesta sessão
- [x] `terraform fmt` e `terraform validate` passam

## 10.11 — Declaração explícita do que NÃO foi executado

**`terraform apply` e `terraform destroy` não foram executados.** Nenhum recurso foi
criado na AWS e nenhum custo foi gerado.

Os critérios de aceite do **PRD 002** que dependem de infraestrutura em execução permanecem
**NÃO VERIFICADOS**:

- dois nós em `Ready` — não verificado
- ausência de endereço público nos nós — não verificado (o plano só mostra a intenção; ver ressalva em 10.5)
- eficácia das marcações de descoberta, com o balanceador de fato recebendo endereço — não verificado
- versão de Kubernetes efetivamente provisionada — não verificada (o plano declara `1.36`)
- ciclo completo de remoção, incluindo o pré-requisito de remover antes o balanceador criado pelo cluster — não exercitado

O que a validação estática prova é que o código é sintaticamente válido, que as referências
entre capacidades resolvem, que a estrutura respeita as quatro regras, e que o plano descreve
a infraestrutura pretendida. O que ela **não** prova: que a nuvem aceita a requisição. Cota,
permissão e disponibilidade de tipo de instância por zona ficam sem cobertura, e um plano
válido pode falhar no `apply` por qualquer um deles.

## Achados

### A-9 — `tfplan` não estava coberto pela exclusão do controle de versão

O `.gitignore` escrito no grupo 1 cobria `*.tfstate`, `.terraform/` e `*.tfvars`, mas **não** o
arquivo de plano. `tfplan` carrega a configuração resolvida do plano inteiro, incluindo valores
que o `plan` já materializou. Num repositório público, é o mesmo tipo de vazamento que a
exclusão do estado existe para evitar. Adicionados `tfplan` e `*.tfplan`.

### A-10 — `terraform.tfvars` gitignorado tem uma consequência que precisa ser dita

A tarefa 1.1 determinou ignorar `*.tfvars` com exceção de `*.tfvars.example`. Cumprido. A
consequência: os valores reais do ambiente `dev` **não** ficam versionados, e um clone limpo
não provisiona sem um passo manual.

Mitigado com `terraform.tfvars.example` carregando os valores de fato usados (nenhum deles é
sensível — região, CIDRs, tipo de instância e contagem), e o passo `cp terraform.tfvars.example
terraform.tfvars` documentado no próprio arquivo. Registrado aqui porque a alternativa —
versionar o `terraform.tfvars` diretamente, já que não há segredo nele — é defensável e é
decisão do responsável, não minha.
