# Container Hardening Report Card

This project demonstrates the evolution of containerizing applications (Go, Node.js, and Python) from naive "it works on my machine" configurations to production-grade, hardened images.

## The Goal
1. **Reduce Cloud Costs & Deployment Time:** Shrink image sizes to consume less storage and boot faster.
2. **Zero-Trust Security:** Eliminate operating system vulnerabilities by stripping away shells, package managers, and utilities.
3. **Least Privilege:** Ensure applications run as restricted, non-root users to mitigate container breakout risks.

## Performance & Security Matrix

| Application | Variant | Image Size | Size Reduction | High / Crit CVEs | Runtime User |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Go** | Naive | 1.23 GB | Baseline | 1,072 (25 Crit) | root |
| **Go** | Slim Multi-Stage | 20.6 MB | **~98.3%** | 25 (1 Crit) | root |
| **Go** | Distroless Non-Root | **13.2 MB** | **~98.9%** | 25 (1 Crit) | **nonroot (65532)** |
| **Node.js** | Naive | 1.58 GB | Baseline | 1,419 (71 Crit) | root |
| **Node.js** | Slim Multi-Stage | 199 MB | **~87.4%** | 27 (1 Crit) | root |
| **Node.js** | Distroless Non-Root | **186 MB** | **~88.2%** | **7 (1 Crit)** | **nonroot (65532)** |
| **Python** | Naive | 1.63 GB | Baseline | 333 (16 Crit) | root |
| **Python** | Slim Multi-Stage | 220 MB | **~86.5%** | 46 (0 Crit) | root |
| **Python** | Distroless Non-Root | **100 MB** | **~93.8%** | 63 (2 Crit) | **nonroot (65532)** |

*Note: Remaining vulnerabilities in the Distroless variants belong to language-specific runtimes or upstream modules, as the base OS attack surface has been fully eliminated.*