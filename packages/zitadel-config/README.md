# Zitadel Config Compositions Package

Zitadel Config composition package provides custom compositions to support operations within and around zitadel

## Installation

To install the Zitadel Config composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: zitadelconfig
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/zitadel-config:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [ZitadelProviderConfig](compositions/zitadel-provider-config/README.md)
2. [PostConfigInit](compositions/post-config-init/README.md)

## Usage


### Example Usage

Example claims are placed withing test scenarious of each composition
