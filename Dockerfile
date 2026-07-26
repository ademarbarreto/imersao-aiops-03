# syntax=docker/dockerfile:1
ARG NODE_VERSION=24-alpine

# ── deps ──────────────────────────────────────────────────────────────
# Só os manifestos de dependência: esta camada só reconstrói quando elas mudam.
# Instalação determinística a partir do lock, sem as dependências de desenvolvimento.
#
# O cache do npm é montado por plataforma (--mount=type=cache é isolado por
# arquitetura no buildx), então nada é reaproveitado entre amd64 e arm64:
# cada variante instala as próprias dependências por inteiro (D1).
FROM node:${NODE_VERSION} AS deps
WORKDIR /app
COPY src/package.json src/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

# ── runtime ───────────────────────────────────────────────────────────
FROM node:${NODE_VERSION} AS runtime

# Init como PID 1: encaminha SIGTERM ao node e faz reap de zumbis.
# Sem isso o `docker compose stop` só retorna no timeout de 10s.
RUN apk add --no-cache dumb-init

ENV NODE_ENV=production
WORKDIR /app

COPY --from=deps --chown=node:node /app/node_modules ./node_modules

# O conteúdo de src/ vira a raiz do WORKDIR — express.static('static') e o
# diretório de views do EJS resolvem pelo CWD do processo (src/server.js:24,27),
# não pela localização do arquivo. COPY . . deixaria os dois um nível acima.
COPY --chown=node:node src/ ./

USER node
EXPOSE 8080

# fetch é global no Node 18+ — evita instalar curl só para o healthcheck.
# Aponta para /health, que a aplicação de fato serve (src/system-life.js:22).
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:8080/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
