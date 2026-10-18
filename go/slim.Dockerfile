FROM golang:1.24-alpine AS build
WORKDIR /app
COPY . .

# Disables cgo to produce a statically linked binary with no libc dependency, allowing it to run on a minimal Alpine runtime.
# Strips DWARF debug symbols and the symbol table to shrink binary size without affecting runtime behavior.
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o server main.go

FROM alpine:3.21
WORKDIR /app
COPY --from=build /app/server .

RUN adduser -D -g "" appuser
USER appuser

EXPOSE 8080
CMD ["./server"]
