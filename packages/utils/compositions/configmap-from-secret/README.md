# ConfigMapfromSecret Composition

This composition allows you to create Kubernetes ConfigMaps by sourcing data from Secret Object keys

## Usage Example

The following test scenarios demonstrate how to use:

- [ConfigMap Creation from Secret](test/scenarios/standard/claim.yaml)

## Configuration

### Parameters

Specifies the source secret, and destination configmap and keys.

```yaml
spec:
  parameters:
    keyMappings:
      - sourceKey: secret-source-key
        destinationKey: destination-cm-key
    sourceSecret:
      namespace: secret-source-namespace
      name: secret-name
    destinationConfigMap:
      namespace: destinaton-cm-namespace
      name: configmap-name
```

### Provider Configuration

Local Kubernetes provider configurations must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  k8sProviderName: KUBERNETES_PROVIDER
```
