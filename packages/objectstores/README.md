# Objectstores crossplane package

Objectstores crossplane package provides custom compositions to support buckets provisioning in Ceph and AWS S3.

## Installation

To install the objectstores composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: objectstores
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/objectstores:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [CephBucket](compositions/ceph-bucket/README.md)
2. [S3Bucket](compositions/s3-bucket/README.md)
3. [ObjectStore](compositions/object-store/README.md)

## Usage

Example claims are placed withing test scenarious of each composition