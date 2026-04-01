# CephBucketUser Composition

This composition creates a Ceph bucket user with Rook CRD and stores credentials in Kubernetes.

## Resource Created

- `CephObjectStoreUser` - Rook CRD resource in the Ceph cluster
- Kubernetes `Secret` - Contains user credentials

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `userName` | string | Yes | Username for Ceph user |
| `displayName` | string | Yes | Display name |
| `namespaceCeph` | string | Yes | K8s namespace for secret |
| `namespaceRook` | string | Yes | Rook Ceph installation namespace |
| `storeName` | string | Yes | Name of Ceph ObjectStore |
| `operationMask` | array | Yes | Allowed operations: read, write, delete |
| `scK8sProviderName` | string | Yes | Storage cluster K8s provider config |
| `ccK8sProviderName` | string | Yes | Control center K8s provider config |

## Example

```yaml
apiVersion: objectstore.mojaloop.io/v1alpha1
kind: CephBucketUser
metadata:
  name: my-ceph-user
spec:
  parameters:
    userName: my-backup-user
    displayName: "My Backup User"
    namespaceCeph: gitlab
    namespaceRook: rook-ceph
    storeName: default
    operationMask:
      - read
      - write
      - delete
    scK8sProviderName: sc-kubernetes-provider
    ccK8sProviderName: kubernetes-provider
```
