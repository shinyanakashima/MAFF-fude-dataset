#!/bin/bash

TARGET_DIR="2025/01"

find "${TARGET_DIR}" -type f -name '*.json' -print0 \
  | while IFS= read -r -d '' f; do
      git mv "$f" "${f%.json}.geojson"
    done

exit 0;

