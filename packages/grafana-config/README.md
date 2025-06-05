# Grafana config Compositions Package

Grafana config composition package provides custom compositions to support operations within and around clusters

## Installation

To install the Grafana config composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: grafana-config
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/grafana-config:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [provider-config](compositions/provider-config/README.md)
2. [OIDC](compositions/oidc/README.md)

## Usage


### Example Usage

Example claims are placed withing test scenarious of each composition
