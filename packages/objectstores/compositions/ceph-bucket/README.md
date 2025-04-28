# Ceph Bucket Composition

This composition creates and manages an Ceph S3 bucket:
- Ceph Bucket using Rook Kubernetes Object Bucket Claim (OBC) CR
- Sync Bucket Access credentials from Storage Cluster to local Kubernetes Cluster
- Push Bucket Credentials to Vault

## Usage Examples

The following test scenarios demonstrate common use cases:

1. [Standard S3 Bucket](test/scenarios/standard/claim.yaml)

### Provider Configuration

Both provider configurations must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
    scK8sProviderName: sc-kubernetes-provider
    ccK8sProviderName: kubernetes-provider
```