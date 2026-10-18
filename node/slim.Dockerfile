FROM node:22-alpine AS build
WORKDIR /app
COPY package.json .

# Excludes devDependencies so test runners, linters, and build tooling are omitted from the production layer.
RUN npm install --omit=dev
COPY . .

FROM node:22-alpine
WORKDIR /app
COPY --from=build /app .

RUN adduser -D -g "" appuser
USER appuser

EXPOSE 3000
CMD ["node", "API_node.js"]
