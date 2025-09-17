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
                path "secret/data/{}/*"{{
                    capabilities = ["read", "list","create","update","delete"]
                }}
                path "secret/metadata/{}/*" {{
                    capabilities = ["read", "list","create","update","delete"]
                }}
                path "secret/data/tenancy/*" {{
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
                """.format(env,env,_unsealkeys[env],_unsealkeys[env],_unsealkeys[env],_unsealkeys[env])
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
} for env in _environments or []]

_items += [_mountObject] + _transitSecretBackendKeys + _transitPolicies

dxr = {
    **oxr
}

items = _items + [dxr]
