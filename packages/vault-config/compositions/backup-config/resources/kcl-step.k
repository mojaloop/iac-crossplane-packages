import base64
import json
# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

## Adding resources
_backendObject = {
    apiVersion = "auth.vault.upbound.io/v1alpha1"
    kind = "Backend"
    metadata = {
        name = "{}-approle-backend".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "approle-backend"
        }
    }
    spec = {
        forProvider = {
            type = "approle"
            path = parameters.snapshotAuthPath
            description = "AppRole auth method enabled via Crossplane"
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
        name = "{}-snapshot-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "snapshot-policy"
        }
    }
    spec = {
        forProvider = {
            name = parameters.snapshotPolicyName
            policy = """
path "sys/storage/raft/snapshot" {
  capabilities = ["read", "create", "update", "sudo"]
}
"""
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_authBackendRoleObject = {
    apiVersion = "approle.vault.upbound.io/v1alpha1"
    kind = "AuthBackendRole"
    metadata = {
        name = "{}-auth-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "snapshot-auth-role"
        }
    }
    spec = {
        forProvider = {
            backendRef = {
                name = "{}-approle-backend".format(oxr.metadata.name)
            }
            roleName = parameters.snapshotRoleName
            tokenPolicies = [parameters.snapshotPolicyName]
            tokenTtl = parameters.snapshotTokenTTL
            secretIdNumUses = parameters.snapshotSecretIdNumUses
            secretIdTtl = parameters.snapshotSecretIdTTL
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}


_authBackendRoleSecretIDObject = {
    apiVersion = "approle.vault.upbound.io/v1alpha1"
    kind = "AuthBackendRoleSecretID"
    metadata = {
        name = "{}-auth-role-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "snapshot-auth-role-secret"
        }
    }
    spec = {
        forProvider = {
            backendRef = {
                name = "{}-approle-backend".format(oxr.metadata.name)
            }
            roleName = parameters.snapshotRoleName
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
        writeConnectionSecretToRef = {
            name = "vault-secret-id-secret"
            namespace = parameters.targetNamespace
        }
    }
}


## Observe Credentials Secret
_observeCredsSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-observe-creds".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "observe-credentials"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "vault-secret-id-secret"
                    namespace = parameters.targetNamespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_snapshot_client_id = base64.encode(ocds["snapshot-auth-role"]?.Resource?.status?.atProvider?.roleId)
_snapshot_client_secret = ocds["observe-credentials"]?.Resource?.status?.atProvider?.manifest?.data["attribute.secret_id"] if ocds["observe-credentials"]?.Resource?.status?.atProvider?.manifest?.data else ""


_snapshotCredsSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-snapshot-creds".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "snapshot-creds"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "vault-snapshot-creds"
                    namespace = parameters.targetNamespace
                }
                data = {
                    VAULT_SNAPSHOT_ROLE_ID = _snapshot_client_id
                    VAULT_SNAPSHOT_SECRET_ID = _snapshot_client_secret
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}


_items += [
    _backendObject
    _authBackendRoleObject
    _policyObject
    _authBackendRoleSecretIDObject
    _observeCredsSecret
    _snapshotCredsSecret
]

dxr = {
    **oxr
}

items = _items + [dxr]
