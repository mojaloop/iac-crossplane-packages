# ObjectStoreUser Composition (Main)

This is the main cloud-agnostic composition that routes to either Ceph or IAM user compositions based on the `objectStoreProvider` parameter.

## Purpose

This composition provides a single unified API for creating object store users across different cloud platforms:
- **Ceph** for private-cloud deployments
- **AWS IAM** for cloud deployments

## How It Works

1. User creates an `ObjectStoreUser` claim with their preferred provider
2. KCL routing function inspects the `objectStoreProvider` parameter
3. If `provider == "ceph"`:
   - Routes to XCephBucketUser composition
   - Creates Ceph user with configurable operations mask
4. If `provider in ["s3", "aws"]`:
   - Routes to XIAMUser composition
   - Creates IAM user with access key

## Parameters

See main [README.md](../../README.md) for complete parameter documentation.

## Example Usage

### Ceph Provider
```yaml
apiVersion: objectstore.mojaloop.io/v1alpha1
kind: ObjectStoreUser
metadata:
  name: backup-user
spec:
  parameters:
    objectStoreProvider: ceph
    userName: backup-user
    displayName: "Backup Service User"
    namespace: backup-system
    ceph:
      operationMask:
        - read
        - write
```

### AWS Provider
```yaml
apiVersion: objectstore.mojaloop.io/v1alpha1
kind: ObjectStoreUser
metadata:
  name: s3-backup-user
spec:
  parameters:
    objectStoreProvider: s3
    userName: s3-backup-user
    displayName: "S3 Backup Service User"
    namespace: backup-system
```

## Routing Logic

The KCL function implements the following logic:

```python
if objectStoreProvider == "ceph":
    # Create XCephBucketUser composition
    # Pass through Ceph-specific parameters
else if objectStoreProvider in ["s3", "aws"]:
    # Create XIAMUser composition
    # Pass through IAM-specific parameters
```

## Composition Template

The composition uses KCL's pipeline function to:
1. Parse the incoming ObjectStoreUser request
2. Route to appropriate sub-composition
3. Return composed resources for Crossplane to manage
4. Apply auto-ready function to detect composition completion
