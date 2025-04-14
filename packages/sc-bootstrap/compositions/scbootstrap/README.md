# Storage Cluster Bootstrap Composition

## Overview

The Storage Cluster Bootstrap composition handles the initial setup phase of a storage cluster, ensuring proper network configuration and establishing GitOps practices from day one.

### Features

- Automated Weave CNI installation and configuration
- ArgoCD deployment with secure defaults
- Initial root application setup for GitOps workflow

## Usage

### Prerequisites

- Control center cluster with Crossplane installed
- Required providers configured:
  - Kubernetes Provider
  - Helm Provider
- Function-KCL installed and configured

### Example claim

```yaml
apiVersion: sc.mojaloop.io/v1alpha1
kind: XSCBootstrap
metadata:
  name: example-bootstrap
  namespace: default
spec:
  parameters:
    argocd:
      chartVersion: "2.9.3"
      application:
        source:
          repoURL: "https://github.com/your-org/gitops-repo"
          path: "clusters/storage"
          targetRevision: "main"
          envVars:
          - name: EXAMPLE_VAR
            value: example-value
  providerConfigsRef:
    scK8sProviderName: sc-kubernetes-provider
    scHelmProviderName: sc-helm-provider
```

### Provider Configuration

Both provider configurations must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  scK8sProviderName: SOURCE_KUBERNETES_PROVIDER
  scHelmProviderName: DESTINATION_KUBERNETES_PROVIDER
```
