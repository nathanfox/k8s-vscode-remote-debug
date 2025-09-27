ARG BUILD_MODE=production

FROM node:22-alpine AS base
WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY src ./src

FROM node:22-alpine AS final
WORKDIR /app

ARG BUILD_MODE
ENV BUILD_MODE=${BUILD_MODE}
ENV NODE_ENV=${BUILD_MODE}

COPY --from=base /app .

EXPOSE 8080
EXPOSE 9229

ENV PORT=8080

CMD ["node", "--inspect=0.0.0.0:9229", "src/index.js"]