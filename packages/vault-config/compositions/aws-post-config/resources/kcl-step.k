# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

## Adding resources
_credentials = {
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "GenericSecret"
    metadata = {
        name = "{}-credentials".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-credentials",
            "crossplane.io/external-name": "vault-credentials"
        }
    }
    spec = {
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProviderName
        }
    }
}

_items += [_credentials]

# Add AWS Object Storage backend if enabled
if parameters.enableObjectStorageBackend:
    _objectStorageBackend = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackend"
        metadata = {
            name = "{}-object-storage-backend".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "vault-object-storage-backend"
            }
        }
        spec = {
            forProvider = {
                path = parameters.objectStorageBackendPath
                accessKey = "access-key-placeholder"  # This will be replaced by actual implementation
                secretKey = "secret-key-placeholder"  # This will be replaced by actual implementation
                region = parameters.region
                defaultLeaseTtlSeconds = parameters.defaultLeaseTtlSeconds
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    _objectStorageRole = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackendRole"
        metadata = {
            name = "{}-object-storage-role".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "vault-object-storage-role"
            }
        }
        spec = {
            forProvider = {
                backend = parameters.objectStorageBackendPath
                name = parameters.objectStorageAccessRole
                credentialType = "assumed_role"
                roleArns = [parameters.objectStorageCloudRole]
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    _items += [_objectStorageBackend, _objectStorageRole]

# Add DNS backend if enabled
if parameters.enableDnsBackend:
    _dnsBackend = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackend"
        metadata = {
            name = "{}-dns-backend".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "vault-dns-backend"
            }
        }
        spec = {
            forProvider = {
                path = parameters.dnsBackendPath
                accessKey = "access-key-placeholder"  # This will be replaced by actual implementation
                secretKey = "secret-key-placeholder"  # This will be replaced by actual implementation
                region = parameters.region
                defaultLeaseTtlSeconds = parameters.defaultLeaseTtlSeconds
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    _dnsAccessRole = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackendRole"
        metadata = {
            name = "{}-dns-access-role".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "vault-dns-access-role"
            }
        }
        spec = {
            forProvider = {
                backend = parameters.dnsBackendPath
                name = parameters.dnsAccessRole
                credentialType = "assumed_role"
                roleArns = [parameters.externalDnsCloudRole]
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    _certManagerAccessRole = {
        apiVersion = "aws.vault.upbound.io/v1alpha1"
        kind = "SecretBackendRole"
        metadata = {
            name = "{}-cert-manager-access-role".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "vault-cert-manager-access-role"
            }
        }
        spec = {
            forProvider = {
                backend = parameters.dnsBackendPath
                name = parameters.certManagerAccessRole
                credentialType = "iam_user"
                policyArns = [parameters.certManagerCloudPolicy]
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }

    _items += [_dnsBackend, _dnsAccessRole, _certManagerAccessRole]


dxr = {
    **oxr
}

items = _items + [dxr]
