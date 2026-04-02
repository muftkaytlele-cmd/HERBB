#!/usr/bin/env bash
set -euo pipefail

cd HerbalTrace/backend
npm ci
npm run build
