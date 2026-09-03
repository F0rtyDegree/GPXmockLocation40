#!/bin/sh
# Скрипт для вывода содержимого всех модулей проекта

find . \
  -path ./android/build -prune -o \
  -path ./build -prune -o \
  -path './.dart_tool' -prune -o \
  -path './.idea' -prune -o \
  -type f \
  \( -name "*.dart" -o -name "*.kt" -o -name "*.java" -o -name "*.swift" -o -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.gradle" -o -name "*.yaml" -o -name "*.xml" -o -name "*.json" -o -name "*.html" \) \
  -exec sh -c 'echo "--- START OF FILE: $1 ---"; cat "$1"; echo "\n--- END OF FILE: $1 ---\n\n"' _ {} \;
