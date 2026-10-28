#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

./diagramas/build.sh
typst compile documentacao.typ documentacao.pdf

echo "PDF gerado em $(pwd)/documentacao.pdf"
