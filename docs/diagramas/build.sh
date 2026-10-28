#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if command -v plantuml >/dev/null 2>&1; then
  plantuml_cmd=(plantuml)
elif [[ -n "${PLANTUML_JAR:-}" ]]; then
  plantuml_cmd=(java -Djava.awt.headless=true -jar "${PLANTUML_JAR}")
else
  echo "PlantUML não encontrado. Instale o pacote plantuml ou defina PLANTUML_JAR." >&2
  exit 1
fi

shopt -s nullglob
puml_files=(./*.puml)

if (( ${#puml_files[@]} == 0 )); then
  echo "Nenhum arquivo .puml encontrado em $(pwd)." >&2
  exit 1
fi

"${plantuml_cmd[@]}" -headless -charset UTF-8 -failfast2 -tsvg "${puml_files[@]}"
"${plantuml_cmd[@]}" -headless -charset UTF-8 -failfast2 -tpng -Sdpi=200 "${puml_files[@]}"

echo "Diagramas gerados: ${#puml_files[@]} fontes em SVG e PNG."
