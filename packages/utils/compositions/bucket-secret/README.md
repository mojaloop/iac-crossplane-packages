# Bucket Secret generation Composition

This composition allows you to extract AWS IAM credentials for writing to s3 bucket and push it to another kubernetes cluster.

## Usage Example

The following test scenarios demonstrate how to use:

- [BucketSecret Creation from Secret](test/scenarios/standard/claim.yaml)

## Configuration

### Parameters

Specify required parameters:

```yaml
spec:
  parameters:
    scAppNamespace: sc-app-namespace
    appNamespace: app-namespace
    bucketsourceSecret: bucket-source-secret
    bucketdestinationSecret: bucket-destination-secret
    bucketName: bucket-name
    credentialsSecret: credentials-secret
  providerConfigsRef:
    scK8sProviderName: sc-kubernetes-provider
    localK8sProviderName: kubernetes-provider
  managementPolicies:
    - "*"
```

### Provider Configuration

Local Kubernetes provider configurations must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  scK8sProviderName: sc-kubernetes-provider
  localK8sProviderName: kubernetes-provider
```
