# OIDC Composition



## Usage Examples

The following test scenarios demonstrate common use cases:

1. [OIDC](test/scenarios/standard/claim.yaml)

## Configuration

```yaml

```

### Provider Configuration

Provider configuration must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  zitadelProviderName: ZITADEL_PROVIDER_CONFIG_NAME
  kubernetesProviderName: KUBERNETES_PROVIDER_CONFIG_NAME
  vaultProviderName: VAULT_PROVIDER_CONFIG_NAME
```
