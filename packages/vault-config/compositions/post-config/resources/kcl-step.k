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
                    name = parameters.credentialsSecretRef?.name
                    namespace = parameters.credentialsSecretRef?.namespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}
## TmpPushSecret object to push credentials to vault
_jsonCreds = {
    "cloud_platform_api_client_id": ocds["observe-credentials"]?.Resource?.status?.atProvider?.manifest?.data["clientId"] if ocds["observe-credentials"]?.Resource?.status?.atProvider?.manifest?.data else ""
    "cloud_platform_api_client_secret": ocds["observe-credentials"]?.Resource?.status?.atProvider?.manifest?.data["clientSecret"] if ocds["observe-credentials"]?.Resource?.status?.atProvider?.manifest?.data else ""
}

_jsonCredsSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-json-creds".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "json-credentials"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-json-creds".format(parameters.credentialsSecretRef?.name)
                    namespace = parameters.credentialsSecretRef?.namespace
                }
                data = {
                    credentials = base64.encode(json.encode(_jsonCreds))
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}
# Generic Vault Secret
# https://marketplace.upbound.io/providers/upbound/provider-vault/v2.1.3/resources/generic.vault.upbound.io/Secret/v1alpha1
_vaultCredsSecret = {
    apiVersion = "generic.vault.upbound.io/v1alpha1"
    kind = "Secret"
    metadata = {
        name = "{}-vault-creds".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-creds"
        }
    }
    spec = {
        forProvider = {
            dataJsonSecretRef = {
                key = "credentials"
                name = "{}-json-creds".format(parameters.credentialsSecretRef?.name)
                namespace = parameters.credentialsSecretRef?.namespace
            }
            path = "secret/cloud-api-access"
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_items += [
    _mountObject
    _backendObject
    _authBackendConfigObject
    _authBackendRoleObject
    _policyObject
    _readPolicyObject
    _observeCredsSecret
    _jsonCredsSecret
    _vaultCredsSecret
]

## AWS Object Storage Backend

# AwsSecretBackend Object storage
# https://marketplace.upbound.io/providers/upbound/provider-vault/v2.1.3/resources/aws.vault.upbound.io/SecretBackend/v1alpha1
if parameters.aws?.objectStorageBackend?.enabled:
    _awsObjectStorageBackend = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackend"
        metadata = {
            name = "{}-aws-object-storage-backend".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "aws-object-storage-backend"
            }
        }
        spec = {
            forProvider = {
                path = parameters.aws?.objectStorageBackend?.path
                region = parameters.aws?.region
                defaultLeaseTtlSeconds = parameters.aws?.defaultLeaseTtlSeconds
                accessKeySecretRef = {
                    key = "clientId"
                    name = parameters.credentialsSecretRef?.name
                    namespace = parameters.credentialsSecretRef?.namespace
                }
                secretKeySecretRef = {
                    key = "clientSecret"
                    name = parameters.credentialsSecretRef?.name
                    namespace = parameters.credentialsSecretRef?.namespace
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    # AwsSecretBackendRole Object storage
    # https://marketplace.upbound.io/providers/upbound/provider-vault/v2.1.3/resources/aws.vault.upbound.io/SecretBackendRole/v1alpha1
    _awsObjectStorageBackendRole = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackendRole"
        metadata = {
            name = "{}-aws-object-storage-role".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "aws-object-storage-role"
            }
        }
        spec = {
            forProvider = {
                backend = parameters.aws?.objectStorageBackend?.path
                name = parameters.aws?.objectStorageBackend?.accessRole
                credentialType = "assumed_role"
                roleArns = [parameters.aws?.objectStorageBackend?.cloudRole]
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }
    _items += [_awsObjectStorageBackend, _awsObjectStorageBackendRole]

## AWS DNS Backend

# AwsSecretBackend DNS Access
# https://marketplace.upbound.io/providers/upbound/provider-vault/v2.1.3/resources/aws.vault.upbound.io/SecretBackend/v1alpha1
if parameters.aws?.dnsBackend?.enabled:
    _awsDnsBackend = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackend"
        metadata = {
            name = "{}-aws-dns-backend".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "aws-dns-backend"
            }
        }
        spec = {
            forProvider = {
                path = parameters.aws?.dnsBackend?.path
                region = parameters.aws?.region
                defaultLeaseTtlSeconds = parameters.aws?.defaultLeaseTtlSeconds
                accessKeySecretRef = {
                    key = "clientId"
                    name = parameters.credentialsSecretRef?.name
                    namespace = parameters.credentialsSecretRef?.namespace
                }
                secretKeySecretRef = {
                    key = "clientSecret"
                    name = parameters.credentialsSecretRef?.name
                    namespace = parameters.credentialsSecretRef?.namespace
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    # AwsSecretBackendRole DNS Access
    # https://marketplace.upbound.io/providers/upbound/provider-vault/v2.1.3/resources/aws.vault.upbound.io/SecretBackendRole/v1alpha1
    _awsDnsBackendRole = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackendRole"
        metadata = {
            name = "{}-aws-dns-role".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "aws-dns-role"
            }
        }
        spec = {
            forProvider = {
                backend = parameters.aws?.dnsBackend?.path
                name = parameters.aws?.dnsBackend?.accessRole
                credentialType = "assumed_role"
                roleArns = [parameters.aws?.dnsBackend?.externalDnsRole]
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    # AwsSecretBackendRole Cert Manager Access
    # https://marketplace.upbound.io/providers/upbound/provider-vault/v2.1.3/resources/aws.vault.upbound.io/SecretBackendRole/v1alpha1
    _awsCertManagerBackendRole = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackendRole"
        metadata = {
            name = "{}-aws-cert-manager-role".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "aws-cert-manager-role"
            }
        }
        spec = {
            forProvider = {
                backend = parameters.aws?.dnsBackend?.path
                name = parameters.aws?.dnsBackend?.certManagerAccessRole
                credentialType = "iam_user"
                policyArns = [parameters.aws?.dnsBackend?.certManagerCloudPolicy]
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    _items += [_awsDnsBackend, _awsDnsBackendRole, _awsCertManagerBackendRole]

dxr = {
    **oxr
}

items = _items + [dxr]
