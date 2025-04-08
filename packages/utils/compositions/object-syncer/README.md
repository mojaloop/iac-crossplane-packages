# ObjectSyncer Composition

This composition allows you to sync Kubernetes objects (like Secrets and ConfigMaps) between different namespaces or clusters.

## Usage Examples

The following test scenarios demonstrate common use cases:

1. [Secret synchronization](test/scenarios/secret/claim.yaml)
2. [ConfigMap synchronization](test/scenarios/configmap/claim.yaml)

## Configuration

### Source Configuration

Specifies the original resource to be synchronized:

```yaml
source:
  namespace: testa  # Source namespace
  name: example-secret  # Source object name
```

### Destination Configuration

Specifies where the synchronized resource should be created:

```yaml
destination:
  namespace: testa  # Target namespace
  name: example-secret  # Target object name
```

### Provider Configuration

Both provider configurations must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  sourceK8sProviderName: SOURCE_KUBERNETES_PROVIDER
  destinationK8sProviderName: DESTINATION_KUBERNETES_PROVIDER
```

#### Provider Permissions

- **Source Provider**: Requires read-only access to source resources
- **Destination Provider**: Requires read and write access to target resources

