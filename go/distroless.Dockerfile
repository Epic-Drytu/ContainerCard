FROM golang:1.24-alpine AS build
WORKDIR /app
COPY . .

# Disables cgo to produce a static binary with no libc dependency, required because distroless/static ships without a C library.
# Strips DWARF debug symbols and the symbol table to shrink binary size without affecting runtime behavior.
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o server main.go

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app

# Copies only the compiled binary so the Go compiler, source files, and build cache stay out of the runtime image.
COPY --from=build /app/server /server

# Distroless static images default to nonroot (UID 65532); declaring it explicitly enforces the security posture for scanners.
USER nonroot:nonroot

EXPOSE 8080
CMD ["/server"]
