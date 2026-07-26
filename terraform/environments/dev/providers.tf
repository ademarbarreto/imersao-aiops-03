# A configuração do provider vive AQUI, no root do ambiente — nunca dentro dos
# módulos. É o que permite que o mesmo módulo seja instanciado em outra região ou
# outra conta apenas criando outra pasta de ambiente.
provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
