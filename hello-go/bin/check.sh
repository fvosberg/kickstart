#!/bin/bash
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

gosec "${PROJECT_ROOT}/..."
golangci-lint run "${PROJECT_ROOT}/..."
