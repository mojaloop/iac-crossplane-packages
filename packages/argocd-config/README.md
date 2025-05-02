# ArgoCD Config Compositions Package

ArgoCD Config composition package provides custom compositions to support operations within and around clusters

## Installation

To install the ArgoCD Config composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: argocdconfig
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/argocd-config:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [OIDC](compositions/oidc/README.md)

## Usage


### Example Usage

Example claims are placed withing test scenarious of each composition
