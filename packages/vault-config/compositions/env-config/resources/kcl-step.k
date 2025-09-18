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


_policyNames = {
  env : ocds["env-transit-{}".format(env)]?.Resource?.status?.atProvider?.name
  for env in _environments or []
}


_envTokens = [] if _policyNames == {} else [{
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
            policies = [_policyNames[env]] if _policyNames[env] else []
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

} for env in _environments or [] if _policyNames.get(env, None) != None
]


_envTokenSecrets = [{
    apiVersion = "generic.vault.upbound.io/v1alpha1"
    kind = "Secret"
    metadata = {
        name = "env-token-secret-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-token-secret-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            dataJsonSecretRef = {
                key = "attribute.client_token"
                name = "env-token-secret-{}".format(env)
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

_items += [_mountObject] + _transitSecretBackendKeys + _transitPolicies + _envTokens + _envTokenSecrets

dxr = {
    **oxr
}

items = _items + [dxr]
