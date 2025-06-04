import json
import base64
import regex as re

# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

# Observe Grafana admin sa secret
_observe_grafana_admin_secret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-grafana-admin-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "grafana-admin-secret-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.grafanaAdminSecretRef.name
                    namespace = parameters.grafanaAdminSecretRef.namespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }

}

# Decode base64 and properly escape JSON content
_grafanaAdminSecretJson = json.decode(base64.decode(ocds["grafana-admin-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?[parameters.grafanaAdminSecretRef.key])) if ocds["grafana-admin-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?[parameters.grafanaAdminSecretRef.key] else {}
_grafanaAdminToken = _grafanaAdminSecretJson["token"] or ""

_grafanaProviderConfigSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-grafana-provider-config-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "grafana-provider-config-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "grafana-provider-config"
                    namespace = spec.claimRef?.namespace or "grafana"
                }
                stringData = {
                    credentials = json.encode({
                        "grafana_service_account_token" = _grafanaAdminToken
                    })
                }
                type = "Opaque"
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_grafanaProviderConfig = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-grafana-provider-config".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "grafana-provider-config"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "grafana.crossplane.io/v1beta1"
                kind = "ProviderConfig"
                metadata = {
                    name = "grafana-provider"
                }
                spec = {
                    name = parameters.providerConfigName
                    credentials = {
                        source = "Secret"
                        secretRef = {
                            name = "grafana-provider-config"
                            namespace = spec.claimRef?.namespace or "grafana"
                            key = "credentials"
                        }
                    }
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

# Add all objects to _items in one line
_items = [_observe_grafana_admin_secret, _grafanaProviderConfigSecret, _grafanaProviderConfig]

dxr = {
    **oxr
}

items = _items + [dxr]
