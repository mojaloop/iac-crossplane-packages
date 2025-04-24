# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

_sc_argocd_operator_app_install = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
      name = "{}-sc-argocd-operator-app-install".format(oxr.metadata.name)
      annotations = {
          "krm.kcl.dev/composition-resource-name": "sc-argocd-operator-app-install"
      }
    }
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "argoproj.io/v1alpha1"
          kind = "Application"
          metadata = {
              name = parameters.operatorArgoAppName
              namespace = "argocd"
          }
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
          spec = {
            project = "default"
            syncPolicy = {
              automated = {
                prune = True
                selfHeal = True
              }
            }
            retry = {
              limit = 20
              backoff = {
                duration = "10s"
                maxDuration = "3m0s"
                factor = 2
              }
            }
            syncOptions = [
              "CreateNamespace=true",
              "PrunePropagationPolicy=foreground",
              "PruneLast=true",
              "ServerSideApply=true"
            ]
            destination = {
              server = "https://kubernetes.default.svc"
              namespace = parameters.operatorNamespace
            }
            source = {
              chart = "kubernetes-operator"
              repoURL = "https://netbirdio.github.io/kubernetes-operator"
              targetRevision = parameters.operatorHelmVersion
              helm = {
                valuesObject = {
                  crds = {
                    enabled = True
                  }
                  cluster = {
                    name = parameters.operatorClusterName
                  }
                  ingress = {
                    enabled = True
                    router = {
                      enabled = True
                    }
                    kubernetesAPI = {
                      enabled = True
                      groups = [parameters.operatorKubeapiGroupName]
                      resourceName: "{}-kube-api".format(parameters.operatorClusterName)
                    }
                  }
                  netbirdAPI = {
                    keyFromSecret = "nb-operator-api-key"
                  }
                  managementURL = parameters.nbManagmentURI
                }
              }
            }
          }
        }
      }
      managementPolicies = spec?.managementPolicies
      providerConfigRef = {
        name = spec?.providerConfigsRef?.scK8sProviderName
      }
    }
}

# Add the resources to the items list
_items += [_sc_argocd_operator_app_install]

dxr = {
  **oxr
}

items = _items + [dxr]
