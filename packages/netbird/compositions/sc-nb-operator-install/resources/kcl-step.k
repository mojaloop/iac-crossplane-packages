# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []


# SC NB Service User
_sc_nb_service_user = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbUser"
  metadata = {
    name = "{}-sc-nb-service-user".format(parameters.serviceUserName)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "sc-nb-service-user"
    }
  }
  spec = {
    forProvider = {
      name = "{}-service-user".format(parameters.serviceUserName)
      is_service_user: true
      role: admin
      auto_groups: []
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = spec?.managementPolicies
  }
}

# SC NB Service User Access Token
_sc_nb_access_token = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbAccessToken"
  metadata = {
    name = "{}-sc-nb-access-token".format(parameters.serviceUserName)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "sc-nb-access-token"
    }
  }
  spec = {
    forProvider = {
      name = "{}-access-token".format(parameters.serviceUserName)
      user_name: ocds["sc-nb-service-user"]?.Resource?.status?.atProvider?.name
      expires_in: parameters.accessTokenExpiresInDays
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = spec?.managementPolicies
  }
}

_nb_access_token_secret_copy = {
    apiVersion = "utils.mojaloop.io/v1alpha1"
    kind = "XObjectSyncer"
    metadata = {
        name = "{}-secret".format(oxr.metadata.name)
    }
    spec = {
        parameters = {
            objectType = "Secret"
            source = {
                name = ocds["sc-nb-access-token"]?.Resource?.spec?.writeConnectionSecretToRef?.name
                namespace = ocds["sc-nb-access-token"]?.Resource?.spec?.writeConnectionSecretToRef?.namespace
            }
            destination = {
                name = "nb-operator-api-key"
                namespace = parameters.nbOperatorNamespace
            }
        }
        providerConfigsRef = {
            sourceK8sProviderName = spec?.providerConfigsRef?.scK8sProviderName
            destinationK8sProviderName = spec?.providerConfigsRef?.ccK8sProviderName
        }
        managementPolicies = spec?.managementPolicies
    }
}

_sc_argocd_nb_operator_app_install = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
      name = "{}-sc-argocd-nb-operator-app-install".format(oxr.metadata.name)
      annotations = {
          "krm.kcl.dev/composition-resource-name": "sc-argocd-nb-operator-app-install"
      }
    }
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "argoproj.io/v1alpha1"
          kind = "Application"
          metadata = {
              name = parameters.nbOperatorArgoAppName
              namespace = parameters.nbOperatorNamespace
          }
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
          spec = {
            project = "default"
            syncPolicy = {
              automated = {
                prune = true
                selfHeal = true
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
              namespace = parameters.nbOperatorNamespace
            }
            source = {
              repoURL = parameters.nbOperatorArgoAppSourceURL
              targetRevision = parameters.nbOperatorArgoAppSourceRevision
              path = "gitops/applications/base/netbird-operator"
              plugin = {
                name = "envsubst"
                env = [
                  {
                    name = "netbird_operator_api_key_secret"
                    value = "nb-operator-api-key"
                  },
                  {
                    name = "netbird_operator_management_url"
                    value = parameters.nbManagmentURI
                  },
                  {
                    name = "netbird_operator_namespace"
                    value = parameters.nbOperatorNamespace
                  },
                  {
                    name = "netbird_operator_helm_version"
                    value = parameters.nbOperatorHelmVersion
                  },
                  {
                    name = "netbird_operator_app_name"
                    value = parameters.nbOperatorArgoAppName
                  }
                ]
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
_items += [
  _sc_nb_service_user,
  _sc_nb_access_token,
  _nb_access_token_secret_copy,
  _sc_argocd_nb_operator_app_install
]

dxr = {
  **oxr
}

items = _items + [dxr]
