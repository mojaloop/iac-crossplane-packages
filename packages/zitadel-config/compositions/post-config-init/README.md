# ZitadelPostConfigInit Composition

## Usage Examples

The following test scenarios demonstrate common use cases:

1. [ZitadelPostConfigInit](test/scenarios/standard/claim.yaml)

## Configuration

```yaml

```

### Provider Configuration

Provider configuration must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  kubernetesProviderName: KUBERNETES_PROVIDER_CONFIG_NAME
```
