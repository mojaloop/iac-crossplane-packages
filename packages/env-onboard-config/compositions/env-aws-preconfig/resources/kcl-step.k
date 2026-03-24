import base64

# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters

_baseName = "{}.{}".format(parameters.ccClusterName, parameters.envName)

# =============================================================================
# 1. IAM User for EBS CSI
# =============================================================================
_iamUser = {
    apiVersion = "iam.aws.upbound.io/v1beta1"
    kind = "User"
    metadata = {
        name = "{}-ebs-csi-user".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "iam-user"
            "crossplane.io/external-name": "{}-AmazonEBSCSIUser".format(_baseName)
        }
    }
    spec = {
        forProvider = {}
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

# =============================================================================
# 2. IAM User Policy Attachment (AmazonEBSCSIDriverPolicy)
# =============================================================================
_iamUserPolicyAttachment = {
    apiVersion = "iam.aws.upbound.io/v1beta1"
    kind = "UserPolicyAttachment"
    metadata = {
        name = "{}-ebs-csi-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "iam-user-policy-attachment"
        }
    }
    spec = {
        forProvider = {
            policyArn = parameters.ebsCsiPolicyArn
            user = "{}-AmazonEBSCSIUser".format(_baseName)
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

# =============================================================================
# 3. IAM Access Key
# =============================================================================
_iamAccessKey = {
    apiVersion = "iam.aws.upbound.io/v1beta1"
    kind = "AccessKey"
    metadata = {
        name = "{}-ebs-csi-access-key".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "iam-access-key"
        }
    }
    spec = {
        forProvider = {
            user = "{}-AmazonEBSCSIUser".format(_baseName)
        }
        writeConnectionSecretToRef = {
            name = "{}-ebs-csi-conn".format(oxr.metadata.name)
            namespace = parameters.envName
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

# =============================================================================
# 4. Observe the AccessKey connection secret to extract credentials
# =============================================================================
_observeAccessKeySecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-ebs-csi-conn-observe".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "ebs-csi-conn-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-ebs-csi-conn".format(oxr.metadata.name)
                    namespace = parameters.envName
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_accessKeyId = base64.decode(ocds["ebs-csi-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["username"]) or ""
_accessKeySecret = base64.decode(ocds["ebs-csi-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["password"]) or ""

# =============================================================================
# 5. Vault KV Secrets - store access key ID and secret
# =============================================================================
_vaultSecrets = []
_k8sSecrets = []


_k8sSecrets += [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-k8s-secret-block-storage-key-id".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "k8s-secret-block-storage-key-id"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-block-storage-key-id".format(oxr.metadata.name)
                    namespace = parameters.envName
                }
                stringData = {
                    value = _accessKeyId
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}]
_vaultSecrets += [{
    apiVersion = "generic.vault.upbound.io/v1alpha1"
    kind = "Secret"
    metadata = {
        name = "{}-block-storage-key-id".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-secret-block-storage-key-id"
        }
    }
    spec = {
        forProvider = {
            path = "{}/{}/block_storage_secret_key_id".format(parameters.vaultKvPath, parameters.envName)
            dataJsonSecretRef = {
                key = "value"
                name = "{}-block-storage-key-id".format(oxr.metadata.name)
                namespace = parameters.envName
            }
            deleteAllVersions = True
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}]


_k8sSecrets += [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-k8s-secret-block-storage-secret-key".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "k8s-secret-block-storage-secret-key"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-block-storage-secret-key".format(oxr.metadata.name)
                    namespace = parameters.envName
                }
                stringData = {
                    value = _accessKeySecret
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}]
_vaultSecrets += [{
    apiVersion = "generic.vault.upbound.io/v1alpha1"
    kind = "Secret"
    metadata = {
        name = "{}-block-storage-secret-key".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-secret-block-storage-secret-key"
        }
    }
    spec = {
        forProvider = {
            path = "{}/{}/block_storage_secret_access_key".format(parameters.vaultKvPath, parameters.envName)
            dataJsonSecretRef = {
                key = "value"
                name = "{}-block-storage-secret-key".format(oxr.metadata.name)
                namespace = parameters.envName
            }
            deleteAllVersions = True
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}]

# =============================================================================
# Assemble all items
# =============================================================================
_items = [
    _iamUser,
    _iamUserPolicyAttachment,
    _iamAccessKey,
    _observeAccessKeySecret,
] + _vaultSecrets + _k8sSecrets

items = _items + [oxr]