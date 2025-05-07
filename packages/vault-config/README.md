# Vault config Compositions Package

Vault config composition package provides custom compositions to support operations within and around clusters

## Installation

To install the Vault config composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: vault-config
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/vault-config:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [PostConfig](compositions/post-config/README.md)

## Usage


### Example Usage

Example claims are placed withing test scenarious of each composition
