# RemoteNamespace Composition

This composition allows you to create remote Namespace on destination K8s cluster

## Usage Examples

The following test scenarios demonstrate common use cases:

1. [RemoteNamespace creation](test/scenarios/standard/claim.yaml)

## Configuration

```yaml
name: NAME_OF_NAMESPACE # Name of namespace to be created on destionation cluster
```

### Provider Configuration

Provider configuration must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  destinationK8sProviderName: DESTINATION_KUBERNETES_PROVIDER
```

#### Provider Permissions

- **Destination Provider**: Requires read and write access to target resources
