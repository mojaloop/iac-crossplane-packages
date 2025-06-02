# K8s Config Compositions Package

K8s Config composition package provides custom compositions to support operations within and around clusters

## Installation

To install the K8s Config composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: k8sconfig
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/k8s-config:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [OIDC](compositions/oidc/README.md)

## Usage


### Example Usage

Example claims are placed withing test scenarious of each composition
