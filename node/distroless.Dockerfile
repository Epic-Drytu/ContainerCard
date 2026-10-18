FROM node:22-alpine AS build
WORKDIR /app
COPY package.json .

# Excludes devDependencies so build tools and test dependencies are kept out of the runtime layer.
RUN npm install --omit=dev
COPY . .

FROM gcr.io/distroless/nodejs22-debian12:nonroot
WORKDIR /app
COPY --from=build /app .

# Distroless Node runs as nonroot (UID 65532) by default; setting it explicitly documents intent and satisfies security linters.
USER nonroot:nonroot

EXPOSE 3000
CMD ["API_node.js"]
