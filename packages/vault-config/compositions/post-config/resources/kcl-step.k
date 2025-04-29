# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

## Adding resources
_mountObject = {
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Mount"
    metadata = {
        name = "{}-mount".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-mount"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        forProvider = {
            path = parameters.kvPath
            type = "kv-v2"
            options = {
                version = "2"
            }
            defaultLeaseTtlSeconds = 120
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_backendObject = {
    apiVersion = "auth.vault.upbound.io/v1alpha1"
    kind = "Backend"
    metadata = {
        name = "{}-backend".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-backend"
        }
    }
    spec = {
        forProvider = {
            type = "kubernetes"
            path = parameters.k8sAdminAuthPath
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_authBackendConfigObject = {
    apiVersion = "kubernetes.vault.upbound.io/v1alpha1"
    kind = "AuthBackendConfig"
    metadata = {
        name = "{}-auth-config".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-auth-config"
        }
    }
    spec = {
        forProvider = {
            kubernetesHost = "https://kubernetes.default.svc:443"
            backendRef = {
                name = "{}-backend".format(oxr.metadata.name)
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_authBackendRoleObject = {
    apiVersion = "kubernetes.vault.upbound.io/v1alpha1"
    kind = "AuthBackendRole"
    metadata = {
        name = "{}-auth-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-auth-role"
        }
    }
    spec = {
        forProvider = {
            backendRef = {
                name = "{}-backend".format(oxr.metadata.name)
            }
            roleName = parameters.k8sAdminRoleName
            boundServiceAccountNames = ["*"]
            boundServiceAccountNamespaces = ["vault"]
            tokenPolicies = [parameters.adminPolicyName]
            tokenTtl = 3600
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_policyObject = {
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Policy"
    metadata = {
        name = "{}-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-policy"
        }
    }
    spec = {
        forProvider = {
            name = parameters.adminPolicyName
            policy = """
path "/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
"""
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_readPolicyObject = {
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Policy"
    metadata = {
        name = "{}-read-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-read-policy"
        }
    }
    spec = {
        forProvider = {
            name = parameters.readKvSecretsPolicyName
            policy = """
path "${parameters.kvPath}/*" {
  capabilities = ["read", "list"]
}
"""
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_items += [_mountObject, _backendObject, _authBackendConfigObject, _authBackendRoleObject, _policyObject, _readPolicyObject]

dxr = {
    **oxr
}

items = _items + [dxr]
