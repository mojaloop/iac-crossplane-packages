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

_pushSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-push-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "push-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "external-secrets.io/v1alpha1"
                kind = "PushSecret"
                metadata = {
                    name = "{}-ebs-csi-push".format(oxr.metadata.name)
                    namespace = parameters.envName
                }
                spec = {
                    updatePolicy = "Replace"
                    deletionPolicy = "None"
                    refreshInterval = "1m"
                    secretStoreRefs = [{
                            name = "vault-secret-store"
                            kind = "ClusterSecretStore"
                    }]
                    selector = {
                        secret = {
                            name = "{}-ebs-csi-conn".format(oxr.metadata.name)
                        }
                    }
                    data = [
                        {
                            match = {
                                secretKey = "username"
                                remoteRef = {
                                    remoteKey = "{}/{}/block_storage_secret_key_id".format(parameters.vaultKvPath, parameters.envName)
                                    property = "value"
                                }
                            }
                        }
                        {
                            match = {
                                secretKey = "password"
                                remoteRef = {
                                    remoteKey = "{}/{}/block_storage_secret_access_key".format(parameters.vaultKvPath, parameters.envName)
                                    property = "value"
                                }
                            }
                        }
                    ]
                }
            }
        }
        readiness = {
            policy = "DeriveFromCelQuery"
            celQuery = '"status" in object && "conditions" in object.status && object.status.conditions.exists(c, c.type == "Ready" && c.status == "True" )'
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

# =============================================================================
# Assemble all items
# =============================================================================
_items = [
    _iamUser,
    _iamUserPolicyAttachment,
    _iamAccessKey,
    _pushSecret,
]

items = _items + [oxr]