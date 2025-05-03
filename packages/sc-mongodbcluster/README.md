# SC MongoDBCluster Composition

This composition creates and manages an Ceph S3 bucket:
- Deploys a Percona Server MongoDB Cluster; It creates a PerconaServerMongoDB custom resource using the Percona Operator.
- It sets up an external AWS Route53 DNS A record pointing to the database cluster's internal IP.
- Manages Database Credentials: It uses an XObjectSyncer to copy the database secret from a namespace in storage cluster to the target application namespace in control center.

## Usage Examples

The following test scenarios demonstrate common use cases:

1. [MongoDBCluster](test/scenarios/standard/claim.yaml)

### Provider Configuration

Both provider configurations must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
    scK8sProviderName: sc-kubernetes-provider
    ccK8sProviderName: kubernetes-provider
    awsProviderName: aws-provider
```