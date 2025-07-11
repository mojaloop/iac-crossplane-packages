# PerconaRole Composition

This composition allows you to create required percona role and bindings for CRs creation of database resources

## Usage Example

The following test scenarios demonstrate how to use:

- [PerconaRole Creation from Secret](test/scenarios/standard/claim.yaml)

## Configuration

### Parameters

Specify required parameters

```yaml
spec:
  parameters:
    clusterName: example-cluster
    appNamespace: example-namespace
    esoPushSecret: true
    esoUpdatePolicy: Replace
    esoDeletePolicy: Delete
    esoRefreshInterval: 1m
    vaultSecretStore: vault-secret-store
    vaultSecretPath: percona/sa-token-secret
  providerConfigsRef:
    scK8sProviderName: sc-kubernetes-provider
    ccK8sProviderName: kubernetes-provider
  managementPolicies:
    - "*"
```

### Provider Configuration

Local Kubernetes provider configurations must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  scK8sProviderName: sc-kubernetes-provider
  ccK8sProviderName: kubernetes-provider
```
