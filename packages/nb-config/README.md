# NetBird Compositions Package

NetBird composition package that helps in configuring and managing NetBird resources through Crossplane.

## Overview

This package provides custom compositions for NetBird, enabling infrastructure as code capabilities for NetBird resources using Crossplane. NetBird is a WireGuard®-based mesh network that connects your devices and servers into a single secure private network.

## Installation

To install the NetBird composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: nb-config
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/nb-config:VERSION
```

## Available Compositions

This package includes the following compositions:

1. PostConfig.nb.mojaloop.io
2. ZitadelUserRolesSyncer.nb.mojaloop.io

## Usage

### Example Usage

Example claims are placed withing test scenarious of each composition

## References

- [NetBird Documentation](https://netbird.io/docs)
- [Crossplane Documentation](https://crossplane.io/docs)
