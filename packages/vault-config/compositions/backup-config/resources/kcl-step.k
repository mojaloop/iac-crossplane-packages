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

if parameters.backupEnabled == True:
    _s3Bucket = {
        apiVersion = "aws.mojaloop.io/v1alpha1"
        kind = "XS3Bucket"
        metadata = {
            name = "{}-vault-backups-bucket".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "vault-backups-bucket"
            }
        }
        spec = {
            parameters = {
                bucket = {
                    bucketName = parameters.backupBucket
                    bucketRegion = parameters?.backup?.bucketRegion
                    forceDestroy = False
                    deletionPolicy = "Delete"
                }
                secret = {
                    name = parameters.backupBucket
                    namespace = parameters.targetNamespace
                }
            }
            providerConfigsRef = {
                awsProviderName = spec?.providerConfigsRef?.awsProviderName
                k8sProviderName = spec.providerConfigsRef.kubernetesProviderName
            }
            managementPolicies = spec.managementPolicies
        }
    }

    _vaultSnapshotCronJob = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-vault-snapshot-cron".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "vault-snapshot-cronjob"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "batch/v1"
                    kind = "CronJob"
                    metadata = {
                        name = "vault-snapshot-cronjob"
                        namespace = parameters.targetNamespace
                    }
                    spec = {
                        schedule = parameters.backupSchedule # Ensure this exists in your parameters
                        jobTemplate = {
                            spec = {
                                template = {
                                    spec = {
                                        volumes = [{ name = "share", emptyDir = {} }]
                                        containers = [
                                            {
                                                name = "snapshot"
                                                image = parameters.vaultBackupImage
                                                imagePullPolicy = "IfNotPresent"
                                                command = ["/bin/sh"]
                                                args = [
                                                    "-ec",
                                                    "export VAULT_SKIP_VERIFY=true\nexport VAULT_TOKEN=$(vault write auth/{}/login role_id=$VAULT_SNAPSHOT_ROLE_ID secret_id=$VAULT_SNAPSHOT_SECRET_ID -format=json | jq -r .auth.client_token);\nvault operator raft snapshot save /share/vault-raft.snap;\n".format(parameters.snapshotAuthPath)
                                                ]
                                                envFrom = [{ secretRef = { name = "vault-snapshot-creds" } }]
                                                env = [{ name = "VAULT_ADDR", value = "http://vault-active.vault.svc.cluster.local:8200" }]
                                                volumeMounts = [{ mountPath = "/share", name = "share" }]
                                            },
                                            {
                                                name = "upload"
                                                image = "amazon/aws-cli:2.2.14"
                                                imagePullPolicy = "IfNotPresent"
                                                command = ["/bin/sh"]
                                                args = [
                                                    "-ec",
                                                    "until [ -f /share/vault-raft.snap ]; do sleep 5; done;\naws s3 cp /share/vault-raft.snap s3://{}/vault_raft_$(date +\"%Y%m%d_%H%M%S\").snap --endpoint-url $AWS_ENDPOINT_URL --no-verify-ssl;\n".format(parameters.backupBucket)
                                                ]
                                                envFrom = [{ secretRef = { name = parameters.backupBucket } }]
                                                volumeMounts = [{ mountPath = "/share", name = "share" }]
                                            }
                                        ]
                                        restartPolicy = "OnFailure"
                                    }
                                }
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


_items += [
    _backendObject
    _authBackendRoleObject
    _policyObject
    _authBackendRoleSecretIDObject
    _observeCredsSecret
    _snapshotCredsSecret
    _s3Bucket
    _vaultSnapshotCronJob
]

dxr = {
    **oxr
}

items = _items + [dxr]
