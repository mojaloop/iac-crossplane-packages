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
                    bucketRegion = parameters.backupBucketRegion
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

    _s3Endpoint = "https://s3.{}.amazonaws.com".format(parameters.backupBucketRegion)

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
                        schedule = parameters.backupSchedule
                        successfulJobsHistoryLimit = 3
                        failedJobsHistoryLimit = 6
                        startingDeadlineSeconds = 600
                        jobTemplate = {
                            spec = {
                                template = {
                                    spec = {
                                        containers = [
                                            {
                                                name = "snapshot-and-upload"
                                                image = parameters.vaultBackupImage
                                                imagePullPolicy = "IfNotPresent"
                                                command = ["/bin/sh"]
                                                args = [
                                                    "-ec",
                                                    """
echo "[$(date)] INFO: Starting Vault Snapshot process..."
export VAULT_SKIP_VERIFY=true

# Validate credentials
if [ -z "$VAULT_SNAPSHOT_ROLE_ID" ] || [ -z "$VAULT_SNAPSHOT_SECRET_ID" ]; then
  echo "[$(date)] ERROR: VAULT_SNAPSHOT_ROLE_ID or VAULT_SNAPSHOT_SECRET_ID is empty. Credentials secret may not be populated yet."
  exit 1
fi

# Authenticate with AppRole
echo "[$(date)] INFO: Authenticating with AppRole..."
export VAULT_TOKEN=$(vault write auth/{auth_path}/login role_id=$VAULT_SNAPSHOT_ROLE_ID secret_id=$VAULT_SNAPSHOT_SECRET_ID -format=json | jq -r .auth.client_token)
if [ -z "$VAULT_TOKEN" ] || [ "$VAULT_TOKEN" = "null" ]; then
  echo "[$(date)] ERROR: Authentication failed, VAULT_TOKEN is empty"
  exit 1
fi

# Take Raft snapshot
SNAP_FILE=/tmp/vault-raft.snap
echo "[$(date)] INFO: Generating Raft snapshot..."
if vault operator raft snapshot save $SNAP_FILE; then
  echo "[$(date)] SUCCESS: Snapshot saved to $SNAP_FILE"
else
  echo "[$(date)] ERROR: Vault snapshot command failed"
  exit 1
fi

# Validate snapshot file exists and is non-empty
if [ ! -s $SNAP_FILE ]; then
  echo "[$(date)] ERROR: Snapshot file is empty or missing"
  exit 1
fi

# Inspect snapshot integrity
echo "[$(date)] INFO: Inspecting snapshot..."
if vault operator raft snapshot inspect $SNAP_FILE; then
  echo "[$(date)] SUCCESS: Snapshot inspection passed"
else
  echo "[$(date)] WARN: Snapshot inspection failed "
  exit 1
fi

LOCAL_SIZE=$(wc -c < $SNAP_FILE | tr -d ' ')
echo "[$(date)] INFO: Local snapshot size: $LOCAL_SIZE bytes"

# Upload to S3
SNAP_NAME=vault_raft_$(date +"%Y%m%d_%H%M%S").snap
S3_PATH=s3://{bucket}/$SNAP_NAME
echo "[$(date)] INFO: Uploading snapshot to $S3_PATH..."
if aws s3 cp $SNAP_FILE $S3_PATH --endpoint-url {s3_endpoint}; then
  echo "[$(date)] SUCCESS: Upload completed successfully"
else
  echo "[$(date)] ERROR: AWS S3 upload failed"
  exit 1
fi

# Verify uploaded file size matches local
S3_SIZE=$(aws s3 ls $S3_PATH --endpoint-url {s3_endpoint} | awk '{{print $3}}')
if [ -z "$S3_SIZE" ]; then
  echo "[$(date)] ERROR: Could not retrieve S3 object size for $SNAP_NAME"
  exit 1
fi
echo "[$(date)] INFO: S3 object size: $S3_SIZE bytes"
if [ "$LOCAL_SIZE" != "$S3_SIZE" ]; then
  echo "[$(date)] ERROR: Size mismatch! Local=$LOCAL_SIZE S3=$S3_SIZE"
  exit 1
fi
echo "[$(date)] SUCCESS: Size verification passed (Local=$LOCAL_SIZE, S3=$S3_SIZE)"
echo "[$(date)] INFO: Vault snapshot backup completed successfully"
                                                    """.format(
                                                        auth_path = parameters.snapshotAuthPath,
                                                        bucket = parameters.backupBucket,
                                                        s3_endpoint = _s3Endpoint
                                                    )
                                                ]
                                                env = [
                                                    { name = "VAULT_ADDR", value = "http://vault-active.vault.svc.cluster.local:8200" }
                                                    {
                                                        name = "VAULT_SNAPSHOT_ROLE_ID"
                                                        valueFrom = {
                                                            secretKeyRef = {
                                                                name = "vault-snapshot-creds"
                                                                key = "VAULT_SNAPSHOT_ROLE_ID"
                                                            }
                                                        }
                                                    }
                                                    {
                                                        name = "VAULT_SNAPSHOT_SECRET_ID"
                                                        valueFrom = {
                                                            secretKeyRef = {
                                                                name = "vault-snapshot-creds"
                                                                key = "VAULT_SNAPSHOT_SECRET_ID"
                                                            }
                                                        }
                                                    }
                                                    {
                                                        name = "AWS_ACCESS_KEY_ID"
                                                        valueFrom = {
                                                            secretKeyRef = {
                                                                name = parameters.backupBucket
                                                                key = "username"
                                                            }
                                                        }
                                                    }
                                                    {
                                                        name = "AWS_SECRET_ACCESS_KEY"
                                                        valueFrom = {
                                                            secretKeyRef = {
                                                                name = parameters.backupBucket
                                                                key = "password"
                                                            }
                                                        }
                                                    }
                                                ]
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
