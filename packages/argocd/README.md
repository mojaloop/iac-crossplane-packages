# ArgoCD Compositions Package

ArgoCD composition package provides custom compositions to support operations within and around clusters

## Installation

To install the ArgoCD composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: argocd
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/argocd:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [OIDC](compositions/oidc/README.md)

## Usage


### Example Usage

Example claims are placed withing test scenarious of each composition
