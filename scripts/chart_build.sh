#!/bin/bash
set -euo pipefail

mkdir -p chart-packages
for chart in charts/*; do
  if [ -f "$chart/Chart.yaml" ]; then
    helm dependency update "$chart"
    helm lint "$chart"
    helm package "$chart" -d chart-packages
  fi
done
