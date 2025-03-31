# Utils Compositions Package

Utils composition package provides custom compositions to support operations within and around clusters

## Installation

To install the Utils composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: utils
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/utils:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [ObjectSyncer.utils.mojaloop.io](compositions/object-syncer/README.md)

## Usage

### Example Usage

Example claims are placed withing test scenarious of each composition
