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

# Observe Zitadel admin sa secret
_observe_zitadel_admin_sa = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-admin-sa".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-admin-sa"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "zitadel-admin-sa"
                    namespace = spec.claimRef?.namespace or "zitadel"
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
_zitadelAdminSaJson = base64.decode(ocds["zitadel-admin-sa"]?.Resource?.status?.atProvider?.manifest?.data?["zitadel-admin-sa.json"] or "")
# Escape double quotes and newlines properly
# _zitadelAdminSaJson = _zitadelAdminSaJsonRaw

_zitadelProviderConfigSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-provider-config-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-provider-config-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "zitadel-provider-config"
                    namespace = spec.claimRef?.namespace or "zitadel"
                }
                stringData = {
                    credentials = json.encode({
                        "domain" = parameters.domain
                        "insecure" = "false"
                        "port" = "443"
                        "jwt_profile_json" = _zitadelAdminSaJson
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

_zitadelProviderConfig = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-provider-config".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-provider-config"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "zitadel.crossplane.io/v1beta1"
                kind = "ProviderConfig"
                metadata = {
                    name = "zitadel-provider"
                }
                spec = {
                    name = parameters.providerConfigName
                    credentials = {
                        source = "Secret"
                        secretRef = {
                            name = "zitadel-provider-config"
                            namespace = spec.claimRef?.namespace or "zitadel"
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
_items = [_observe_zitadel_admin_sa, _zitadelProviderConfigSecret, _zitadelProviderConfig]

dxr = {
    **oxr
}

items = _items + [dxr]
