FROM golang:1.24-alpine
WORKDIR /app

# Keeps the full Go toolchain and runs as root to serve as an unhardened baseline for size and vulnerability comparisons.
COPY . .
RUN go build -o server main.go

EXPOSE 8080
CMD ["./server"]
