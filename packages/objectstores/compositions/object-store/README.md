# ObjectStore Bucket Composition

This composition is a wrapper to AWS S3 bucket and Ceph Bucket composition:
- Create AWS S3 Bucket
- Create Ceph Rados Bucket

## Usage Examples

The following test scenarios demonstrate common use cases:

1. [Standard AWS S3 Bucket](test/scenarios/s3/claim.yaml)
2. [Standard Ceph Bucket](test/scenarios/ceph/claim.yaml)

### Provider Configuration

Both provider configurations must be present on the cluster where the claim is deployed:

- **AWS S3**

```yaml
spec:
  s3:
    awsProviderName: "aws-cp-upbound-provider-config"
```

- **Ceph**

```yaml
spec:
  ceph:
    scK8sProviderName: "sc-kubernetes-provider"
    ccK8sProviderName: "kubernetes-provider"
```
