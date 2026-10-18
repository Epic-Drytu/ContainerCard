#!/usr/bin/env bash
set -euo pipefail

APPS=(go node python)
VARIANTS=(naive slim distroless)

check_deps() {
    local missing=0
    for cmd in docker trivy; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: ${cmd} is not installed."
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        exit 1
    fi
}

get_port() {
    case $1 in
        go)     echo 8080 ;;
        node)   echo 3000 ;;
        python) echo 5000 ;;
    esac
}

get_endpoint() {
    # Go's only handler is /hello; Node and Python both serve /
    case $1 in
        go) echo "/hello" ;;
        *)  echo "/" ;;
    esac
}

build_image() {
    local app=$1
    local variant=$2
    local tag="cc-${app}-${variant}"

    local start end
    start=$(date +%s)
    docker build -q -t "$tag" -f "${app}/${variant}.Dockerfile" "${app}/" >/dev/null
    end=$(date +%s)

    echo $((end - start))
}

get_size_mb() {
    local tag=$1
    # docker inspect reports bytes; awk converts to MB with one decimal
    docker image inspect "$tag" --format '{{.Size}}' \
        | awk '{printf "%.1f", $1 / 1048576}'
}

smoke_test() {
    local tag=$1
    local app=$2
    local port endpoint cid code

    port=$(get_port "$app")
    endpoint=$(get_endpoint "$app")

    cid=$(docker run -d -p "8888:${port}" "$tag" 2>/dev/null)
    sleep 1

    code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8888${endpoint}" 2>/dev/null || echo "000")

    docker stop "$cid" >/dev/null 2>&1
    docker rm "$cid" >/dev/null 2>&1

    if [ "$code" = "200" ]; then
        echo "pass"
    else
        echo "FAIL (${code})"
    fi
}

scan_cves() {
    local tag=$1
    local output high critical

    output=$(trivy image --severity HIGH,CRITICAL --quiet "$tag" 2>/dev/null || true)

    # trivy prints one summary line per scan target; sum them all
    high=$(echo "$output" | grep -o 'HIGH: [0-9]*' | awk '{s+=$2} END {print s+0}')
    critical=$(echo "$output" | grep -o 'CRITICAL: [0-9]*' | awk '{s+=$2} END {print s+0}')

    echo "${high} ${critical}"
}

# --- main ---

check_deps

echo ""
echo "Scan date: $(date '+%Y-%m-%d')"
echo "Trivy: $(trivy --version | head -1)"
echo "Hardware: [FILL IN: e.g. Apple M2, 16 GB RAM]"
echo ""

declare -a TAGS=()
declare -a SIZES=()
declare -a TIMES=()
declare -a HIGHS=()
declare -a CRITS=()
declare -a SMOKES=()

for app in "${APPS[@]}"; do
    for variant in "${VARIANTS[@]}"; do
        tag="cc-${app}-${variant}"
        echo "Building ${tag}..."

        build_time=$(build_image "$app" "$variant")
        size=$(get_size_mb "$tag")
        smoke=$(smoke_test "$tag" "$app")

        echo "Scanning ${tag}..."
        read -r high critical <<< "$(scan_cves "$tag")"

        TAGS+=("$tag")
        SIZES+=("$size")
        TIMES+=("$build_time")
        HIGHS+=("$high")
        CRITS+=("$critical")
        SMOKES+=("$smoke")
    done
done

echo ""
echo "## All images"
echo ""
printf "| %-25s | %9s | %14s | %9s | %13s | %10s |\n" \
    "Image" "Size (MB)" "Build time (s)" "HIGH CVEs" "CRITICAL CVEs" "Smoke test"
printf "|%-27s|%11s|%16s|%11s|%15s|%12s|\n" \
    "---------------------------" "-----------" "----------------" "-----------" "---------------" "------------"

for i in "${!TAGS[@]}"; do
    printf "| %-25s | %9s | %14s | %9s | %13s | %10s |\n" \
        "${TAGS[$i]}" \
        "${SIZES[$i]}" \
        "${TIMES[$i]}" \
        "${HIGHS[$i]}" \
        "${CRITS[$i]}" \
        "${SMOKES[$i]}"
done

echo ""
echo "## Slim vs Distroless"
echo ""
printf "| %-25s | %9s | %9s | %13s |\n" \
    "Image" "Size (MB)" "HIGH CVEs" "CRITICAL CVEs"
printf "|%-27s|%11s|%11s|%15s|\n" \
    "---------------------------" "-----------" "-----------" "---------------"

for i in "${!TAGS[@]}"; do
    tag="${TAGS[$i]}"
    if [[ "$tag" == *-slim ]] || [[ "$tag" == *-distroless ]]; then
        printf "| %-25s | %9s | %9s | %13s |\n" \
            "$tag" \
            "${SIZES[$i]}" \
            "${HIGHS[$i]}" \
            "${CRITS[$i]}"
    fi
done

echo ""
echo "Naive images are local only and not pushed to the registry."
echo ""
