# ContainerCard

Nine Docker images: three trivial APIs (Go, Node, Python) each built three
ways — naive, slim, and distroless. The goal is to measure what each approach
costs and saves in image size and CVE exposure.

The apps are intentionally simple. The Dockerfiles, scan pipeline, and the
analysis below are the actual work.

## What's in here

```
go/       naive.Dockerfile  slim.Dockerfile  distroless.Dockerfile  main.go
node/     naive.Dockerfile  slim.Dockerfile  distroless.Dockerfile  API_node.js  package.json
python/   naive.Dockerfile  slim.Dockerfile  distroless.Dockerfile  app.py  requirements.txt
scripts/  scan.sh
```

**Naive** — single-stage build, full base image, runs as root. No hardening.
Used as the baseline to make the comparison meaningful.

**Slim** — multi-stage build. Only the compiled output (or production
dependencies) is copied into a minimal runtime image. Runs as a non-root user.

**Distroless** — multi-stage build. Runtime image ships no shell, no package
manager, and no system utilities. Only the app and its direct runtime
dependencies. Runs as nonroot.

## How to run the scan

Prerequisites: Docker, Trivy.

```bash
bash scripts/scan.sh
```

The script builds all nine images locally, runs Trivy on each, smoke-tests
every container with a curl request, and prints the tables below. Naive images
are built for local comparison only and are not pushed to the registry.

## Results

Latest verification attempt: 2026-10-29 — **not completed**. `bash scripts/scan.sh`
could not connect to the Docker daemon at
`~/.docker/run/docker.sock`, so no images were built or scanned and no smoke
tests ran. The benchmark below remains the snapshot from 2026-10-18.

Scan date: 2026-10-18
Trivy version: 0.76.0
Hardware: M4, 16 RAM

### All images

| Image                | Size (MB) | Build time (s) | HIGH CVEs | CRITICAL CVEs | Smoke test |
|----------------------|-----------|----------------|-----------|---------------|------------|
| cc-go-naive          |     483.9 |              2 |       477 |             2 |       pass |
| cc-go-slim           |      19.3 |              1 |        24 |             0 |       pass |
| cc-go-distroless     |      13.0 |              1 |        22 |             0 |       pass |
| cc-node-naive        |     240.3 |              1 |        11 |             0 |       pass |
| cc-node-slim         |     228.2 |              1 |        11 |             0 |       pass |
| cc-node-distroless   |     206.7 |              1 |         6 |             1 |       pass |
| cc-python-naive      |     212.9 |              7 |        44 |             0 |       pass |
| cc-python-slim       |     200.5 |              6 |        44 |             0 |       pass |
| cc-python-distroless |      95.3 |              7 |        61 |             2 |       pass |

### Slim vs distroless

| Image                | Size (MB) | HIGH CVEs | CRITICAL CVEs |
|----------------------|-----------|-----------|---------------|
| cc-go-slim           |      19.3 |        24 |             0 |
| cc-go-distroless     |      13.0 |        22 |             0 |
| cc-node-slim         |     228.2 |        11 |             0 |
| cc-node-distroless   |     206.7 |         6 |             1 |
| cc-python-slim       |     200.5 |        44 |             0 |
| cc-python-distroless |      95.3 |        61 |             2 |

## What I found

The Go result was the most straightforward — naive at 483 MB dropped to 13 MB
in distroless because the entire compiler toolchain disappears from the final
image.

The Python result surprised me. I expected distroless to be safer than slim
because of its smaller size, but the outcome was the opposite: 61 HIGH and 2
CRITICAL CVEs versus slim's 44 HIGH and 0 CRITICAL. After looking into it, the
Debian 12 base that Python distroless uses carries packages with known CVEs that
the Python slim base does not. Smaller image does not mean fewer vulnerabilities.

Node followed the same pattern — distroless gained 1 CRITICAL CVE that the slim
variant does not have, while only saving 21 MB in size.

**Build times were a non-issue.** All nine images built in 1–7 seconds on the
first run (with layer caching). Python is slower because pip resolves and
installs Flask dependencies; Go and Node compile or copy faster. Multi-stage
builds added no meaningful overhead over naive ones.

## Honest limits

The APIs are trivial on purpose. Flask's development server is used in the
Python images. The Go server has no graceful shutdown on SIGTERM. Node has no
health endpoint beyond `/`. Adding production features would change the image
comparison without adding signal about the images themselves.

What distroless actually does: it removes the shell, package manager, and most
system utilities from the final image. This reduces the number of packages Trivy
scans and limits what an attacker can execute if they get in. It does not
eliminate CVEs — the Python results show that directly. It does not prevent
container breakout.

CVE counts change daily as new vulnerabilities are disclosed and base images are
patched. The numbers above are a snapshot from the scan date, not a permanent
score.

## How the CI works

Pushing to `main` builds and publishes slim and distroless images to GHCR.
Naive images build locally only.

Published images:

```
ghcr.io/epic-drytu/containercard/go-api:slim
ghcr.io/epic-drytu/containercard/go-api:distroless
ghcr.io/epic-drytu/containercard/node-api:slim
ghcr.io/epic-drytu/containercard/node-api:distroless
ghcr.io/epic-drytu/containercard/python-api:slim
ghcr.io/epic-drytu/containercard/python-api:distroless
```

Each image is built for `linux/amd64` and `linux/arm64` with an attached SBOM
and provenance attestation.

## AI disclosure

The three API files (`main.go`, `API_node.js`, `app.py`) were generated with AI
assistance and reviewed by me. The Dockerfiles, scan script, CI workflow, and
the analysis in this README are mine.
