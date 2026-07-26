# Registros de decisão arquitetural (ADR)

Cada arquivo registra uma decisão tomada, o contexto em que foi tomada, as alternativas
descartadas e a consequência aceita. Um ADR não é revisado quando a decisão muda — é
substituído por outro que o supersede, para que o histórico do raciocínio continue legível.

As seis decisões abaixo vêm da mudança `containerizacao-infra-e-deploy` (2026-07-26).

| # | Decisão | Estado |
|---|---|---|
| [001](001-imagem-multiplataforma.md) | Imagem multiplataforma com construção independente por arquitetura | Aceita |
| [002](002-build-local-e-publicacao-separados.md) | Caminho de construção local separado do de publicação | Aceita |
| [003](003-estado-do-provisionamento-local.md) | Estado do provisionamento local, e não remoto | Aceita, com risco assumido |
| [004](004-provisionamento-nao-aplica-manifestos.md) | Provisionamento de infraestrutura não aplica manifestos | Aceita |
| [005](005-banco-no-cluster-sem-volume.md) | Banco no cluster sem armazenamento persistente | Aceita, decisão de laboratório |
| [006](006-validacao-em-cluster-local.md) | Validação em cluster local, sem adaptar o manifesto | Aceita |
