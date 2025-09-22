import base64
import json
# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

_environments = (parameters?.environments or "").split(",")


## Adding resources
_mountObject = {
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Mount"
    metadata = {
        name = "transit-mount"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "transit-mount"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        forProvider = {
            path = "transit"
            type = "transit"
            description = "Transit secrets engine for unsealing and encryption"

        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
}

_transitSecretBackendKeys = [{
    apiVersion = "transit.vault.upbound.io/v1alpha1"
    kind = "SecretBackendKey"
    metadata = {
        name = "unseal-key-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "unseal-key-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            backendSelector = {
                matchControllerRef = True
            }
            name = "unseal-key-{}".format(env)
            deletionAllowed = True
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
} for env in _environments or []]


_unsealkeys = {
  env : ocds["unseal-key-{}".format(env)]?.Resource?.status?.atProvider?.name or ""
  for env in _environments or []
}

_transitPolicies = [{
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Policy"
    metadata = {
        name = "env-transit-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "env-transit-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            name = "env-transit-{}".format(env)
            policy = """
                path "{}/data/{}/*"{{
                    capabilities = ["read", "list","create","update","delete"]
                }}
                path "{}/metadata/{}/*" {{
                    capabilities = ["read", "list","create","update","delete"]
                }}
                path "{}/data/tenancy/*" {{
                    capabilities = ["read", "list"]
                }}
                path "auth/token/*" {{
                    capabilities = ["read","create","update"]
                }}
                path "transit/encrypt/{}" {{
                capabilities = [ "update" ]
                }}

                path "transit/decrypt/{}" {{
                capabilities = [ "update" ]
                }}

                path "transit/encrypt/{}-migrated" {{
                capabilities = [ "update" ]
                }}

                path "transit/decrypt/{}-migrated" {{
                capabilities = [ "update" ]
                }}
                """.format(parameters.kvPath,env,parameters.kvPath,env,parameters.kvPath,_unsealkeys[env],_unsealkeys[env],_unsealkeys[env],_unsealkeys[env])
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
} for env in _environments or []]


_envTokens = [{
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Token"
    metadata = {
        name = "env-token-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "env-token-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            policies = ["env-transit-{}".format(env)]
            noParent = True
            ttl = parameters?.envTokenTTL

        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
        writeConnectionSecretToRef = {
            name = "env-token-secret-{}".format(env)
            namespace = env
        }
    }

} for env in _environments or []
]

_k8sObserveSecret = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "env-token-k8secret-observe-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-token-k8secret-observe-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "env-token-secret-{}".format(env)
                    namespace = env
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}for env in _environments or []
]

_jsonPayload = {
    env: {
        "value": base64.decode(
            ocds["env-token-k8secret-observe-{}".format(env)]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_token"]
        ) if ocds["env-token-k8secret-observe-{}".format(env)]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_token"] else None
    }
    for env in _environments or []
}

_k8sSecrets = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "env-token-k8secret-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-token-k8secret-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "env-token-k8secret-{}".format(env)
                    namespace = env
                }
                data = {
                    "credentials" = base64.encode(json.encode(_jsonPayload[env]))
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}for env in _environments or []
]


_envTokenSecrets = [{
    apiVersion = "generic.vault.upbound.io/v1alpha1"
    kind = "Secret"
    metadata = {
        name = "env-token-vault-secret-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-token-vault-secret-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            dataJsonSecretRef = {
                key = "credentials"
                name = "env-token-k8secret-{}".format(env)
                namespace = env
            }
            deleteAllVersions = True
            path = "{}/{}/env_token".format(parameters.kvPath, env)
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
}for env in _environments or []]


_unsealVariables = [ {
    apiVersion = "projects.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata = {
        name = "project-var-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "project-var-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            projectIdSelector = {
                matchLabels = {
                   "gitlab.mojaloop.com/project-name" = env
                }
            }
            key = "TRANSIT_VAULT_UNSEAL_KEY_NAME"
            value = _unsealkeys[env]
            protected = False
            masked = False
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
} for env in _environments or []
]

_items += [_mountObject] + _transitSecretBackendKeys + _transitPolicies + _envTokens + _k8sObserveSecret + _k8sSecrets + _envTokenSecrets + _unsealVariables

dxr = {
    **oxr
}

items = _items + [dxr]
