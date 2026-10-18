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

**Go had the most dramatic results.** The naive image is 483.9 MB with 477 HIGH
and 2 CRITICAL CVEs — almost entirely from the compiler toolchain and full Debian
layer that get bundled in. The distroless image is 13 MB with 22 HIGH and 0
CRITICAL. The entire Go toolchain, standard library source, and most of the OS
disappear because the binary is statically linked (`CGO_ENABLED=0`) and copied
alone into the runtime image.

**Python distroless is the counterintuitive result.** Python slim has 44 HIGH
CVEs and 0 CRITICAL. Python distroless has 61 HIGH and 2 CRITICAL — more than
slim on both counts, despite being less than half the size. The size drop (200.5
MB to 95.3 MB) is real: distroless removes the shell and most system packages.
But the Debian 12 base that distroless uses carries CVEs that the Python slim
base (also Debian, but with different package pinning) does not. Smaller does
not automatically mean safer.

<!-- Fill in one or two sentences here about what this told you personally.
     For example: did this change how you thought about distroless?
     Was the Python result something you expected or not?
     Keep it to 2-3 sentences in your own words. -->

**Node distroless introduced a CRITICAL CVE that slim does not have.** Slim and
distroless are close in size (228.2 MB vs 206.7 MB), but distroless picks up 1
CRITICAL CVE. The reduction in HIGH CVEs (11 to 6) comes from removing system
packages, but the CRITICAL comes from a package inside the Node 22 distroless
base image itself.

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
