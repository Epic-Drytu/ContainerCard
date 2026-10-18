FROM node:22-alpine
WORKDIR /app

# Installs dependencies directly and runs as root to establish an unhardened baseline for size and CVE comparisons.
COPY package.json .
RUN npm install
COPY . .

EXPOSE 3000
CMD ["node", "API_node.js"]
