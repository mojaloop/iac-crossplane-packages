# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

_backupScheduleSnippet = []
if parameters?.backup?.enabled == True:
    _backupScheduleSnippet =  [
        {
            name =  parameters?.backup?.scheduleName,
            schedule =  parameters?.backup?.cronScheduleExpression,
            keep =  parameters?.backup?.backupRetention,
            storageName =  "s3-backup-storage"
        }
    ]


## Adding resources
_MysqlCluster = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-pxc".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "percona-sql-db"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "pxc.percona.com/v1"
                kind = "PerconaXtraDBCluster"
                metadata = {
                    name = parameters.clusterName
                    namespace = parameters.scAppNamespace
                }
                spec = {
                    crVersion = parameters?.crVersion
                    unsafeFlags = {
                        tls = True
                        pxcSize = True
                        proxySize = True
                        backupIfUnhealthy = True
                    }
                    imagePullPolicy = "IfNotPresent"
                    secretsName = parameters?.dbSecret
                    pxc = {
                            size = parameters?.pxc?.replicas
                            image = parameters?.pxc?.image
                            imagePullPolicy = parameters?.pxc?.imagePullPolicy
                            affinity = {
                                antiAffinityTopologyKey = "kubernetes.io/hostname"
                            }
                            podDisruptionBudget = {
                                maxUnavailable = parameters?.pxc?.podDisruptionBudget?.maxUnavailable
                                minAvailable = parameters?.pxc?.podDisruptionBudget?.minAvailable
                            } if parameters?.pxc?.podDisruptionBudget else {}

                            gracePeriod = 600

                            if parameters?.pxc?.annotations: annotations = parameters?.pxc?.annotations
                            volumeSpec = parameters?.pxc?.volumeSpec if parameters?.pxc?.volumeSpec else {
                                accessModes = [
                                    "ReadWriteOnce"
                                ]
                                persistentVolumeClaim = {
                                    resources = {
                                        requests =  {
                                            storage = parameters?.pxc?.storageSize
                                        }
                                    }
                                }
                            }

                            resources = {
                                requests =  {
                                    cpu = parameters?.pxc?.resources?.requests?.cpu
                                    memory = parameters?.pxc?.resources?.requests?.memory
                                }
                                limits = {
                                    cpu = parameters?.pxc?.resources?.limits?.cpu
                                    memory = parameters?.pxc?.resources?.limits?.memory
                                }
                            }

                            configuration = parameters?.pxc?.configuration

                            priorityClassName = parameters?.pxc?.priorityClassName

                            tolerations = parameters?.pxc?.tolerations
                        }
                    haproxy = {
                        enabled = True
                        size = parameters?.haproxy?.replicas
                        image = parameters?.haproxy?.image
                        imagePullPolicy = parameters?.haproxy?.imagePullPolicy
                        affinity = {
                            antiAffinityTopologyKey = "kubernetes.io/hostname"
                        }
                        podDisruptionBudget = {
                            maxUnavailable = parameters?.haproxy?.podDisruptionBudget?.maxUnavailable
                            minAvailable = parameters?.haproxy?.podDisruptionBudget?.minAvailable
                        } if parameters?.pxc?.podDisruptionBudget else {}

                        exposePrimary = {
                            type = parameters?.haproxy?.expose?.type
                            annotations = parameters?.haproxy?.expose?.annotations
                            labels = parameters?.haproxy?.expose?.labels
                        }
                        gracePeriod = 30
                        resources = {
                            requests = {
                                cpu = parameters?.haproxy?.resources?.requests?.cpu
                                memory = parameters?.haproxy?.resources?.requests?.memory
                            }
                            limits = {
                                cpu = parameters?.haproxy?.resources?.limits?.cpu
                                memory = parameters?.haproxy?.resources?.limits?.memory
                            }
                        }

                        priorityClassName = parameters?.haproxy?.priorityClassName

                        tolerations = parameters?.haproxy?.tolerations
                    }
                    logcollector = {
                        enabled = True
                        image = parameters?.logcollector?.image
                        imagePullPolicy = parameters?.logcollector?.imagePullPolicy
                        resources = {
                            requests = {
                                cpu = parameters?.logcollector?.resources?.requests?.cpu
                                memory = parameters?.logcollector?.resources?.requests?.memory
                            }

                            limits = {
                                cpu = parameters?.logcollector?.resources?.limits?.cpu
                                memory = parameters?.logcollector?.resources?.limits?.memory
                            }

                        }
                    }
                    backup = {
                    image = parameters?.backup?.image
                    imagePullPolicy = parameters?.backup?.imagePullPolicy
                    storages = {
                        "s3-backup-storage" = {
                            type = "s3"
                            verifyTLS = parameters?.backup?.verifyTLS
                            s3 = {
                                bucket = parameters?.backup?.bucket
                                credentialsSecret = parameters?.backup?.credentialsSecret
                                region = parameters?.backup?.bucketRegion
                            }
                        }
                        if parameters?.backup?.pvc : "fs-pvc" = parameters?.backup?.pvc
                    }
                    schedule = _backupScheduleSnippet
                   }
                }
            }
        }
        #readiness = {
        #    policy = "DeriveFromCelQuery"
        #    celQuery = '"status" in object && "conditions" in object.status && object.status.conditions.exists(c, c.type == "ready" && c.status == "True" )'
        #}
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.scK8sProviderName
        }
    }
}

_Secret = {
    apiVersion = "utils.mojaloop.io/v1alpha1"
    kind = "XObjectSyncer"
    metadata = {
        name = "{}-secret".format(oxr.metadata.name)
    }
    spec = {
        parameters = {
            objectType = "Secret"
            source = {
                name = parameters?.dbsourceSecret
                namespace = parameters?.scAppNamespace
            }
            destination = {
                name = parameters?.dbSecret
                namespace = parameters?.appNamespace
            }
        }
        providerConfigsRef = {
            sourceK8sProviderName = spec?.providerConfigsRef?.scK8sProviderName
            destinationK8sProviderName = spec?.providerConfigsRef?.ccK8sProviderName
        }
        managementPolicies = spec?.managementPolicies
    }
}

_clientsourceSecret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-client-tls-ss".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "client-tls-ss"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "Secret"
        metadata = {
          name = "{}-ssl".format(parameters.clusterName)
          namespace = parameters?.scAppNamespace
        }
      }
    }
    managementPolicies = ["Observe"]
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}


_tlsRawData = ocds["client-tls-ss"]?.Resource?.status?.atProvider?.manifest?.data
_tlsData = _tlsRawData if _tlsRawData != None else {}

_tlsCrt = base64.decode(str(_tlsData["tls.crt"])).strip() if "tls.crt" in _tlsData else ""
_tlsKey = base64.decode(str(_tlsData["tls.key"])).strip() if "tls.key" in _tlsData else ""
_tlscaCrt = base64.decode(str(_tlsData["ca.crt"])).strip() if "tls.crt" in _tlsData else ""

_caBundle = "{}\n{}\n{}".format(_tlsCrt, _tlsKey, _tlscaCrt)

_ConsumerAppCASecrets = [
  {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
      name = "{}-ca-secret-{}".format(oxr.metadata.name, secretNs)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "ca-secret-{}".format(secretNs)
      }
    }
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "v1"
          kind = "Secret"
          metadata = {
            name = parameters?.consumerAppsSecret?.name
            namespace = secretNs
          }
          type = "Opaque"
          stringData = {
            parameters?.consumerAppsSecret?.key: _caBundle
          }
        }
      }
      managementPolicies = ["*"]
      providerConfigRef = {
        name = spec.providerConfigsRef.ccK8sProviderName
      }
    }
  } for secretNs in parameters?.consumerAppsSecret?.namespaces or []
]

_ip = [ocds["percona-sql-db"]?.Resource?.status?.atProvider?.manifest?.status?.host] if ocds["percona-sql-db"]?.Resource?.status?.atProvider?.manifest?.status?.host else []

_DnsRecord = {
    apiVersion = "utils.aws.mojaloop.io/v1alpha1"
    kind = "XAWSRoute53Record"
    metadata = {
        name = "{}-dnsrecord".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "dns-record"
        }
    }

    spec = {
        parameters = {
            name = parameters?.dns?.name
            region = parameters?.dns?.region
            ttl =  parameters?.dns?.ttl
            type =  parameters?.dns?.type
            records = _ip
            zoneId = parameters?.dns?.zoneId
        }
        providerConfigsRef = {
            awsProviderConfigName = spec?.providerConfigsRef?.awsProviderName
        }
        managementPolicies = spec.managementPolicies
    }
}

_ns = parameters?.backup?.appNamespace if parameters?.backup?.appNamespace else parameters?.appNamespace

if parameters?.backup?.enabled == True:
    _s3Bucket = {
        apiVersion = "aws.mojaloop.io/v1alpha1"
        kind = "XS3Bucket"
        metadata = {
            name = "{}-backups-bucket".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "backups-bucket"
            }
        }
        spec = {
            parameters = {
                bucket = {
                    bucketName = parameters?.backup?.bucket
                    bucketRegion = parameters?.backup?.bucketRegion
                    forceDestroy = parameters?.backup?.forceDestroy
                    deletionPolicy = parameters?.backup?.deletionPolicy
                }
                secret = {
                    name = parameters?.backup?.credentialsSecret
                    namespace = parameters?.appNamespace
                    esoPushSecret = false
                }
            }
            providerConfigsRef = {
                awsProviderName = spec?.providerConfigsRef?.awsProviderName
                k8sProviderName = spec.providerConfigsRef.ccK8sProviderName
            }
            managementPolicies = spec.managementPolicies
        }
    }

    # Bundle s3 backup K8s bits into one Object
    _BucketBackupsBundle = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-bucket-backups-bundle".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "bucket-backups-bundle"
            }
        }
        spec = {
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.ccK8sProviderName
            }
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "List"
                    items = [

                        # ServiceAccount
                        {
                            apiVersion = "v1"
                            kind = "ServiceAccount"
                            metadata = {
                                name = "{}-secret-creator".format(oxr.metadata.name)
                                namespace = _ns
                            }
                        },

                        # Role
                        {
                            apiVersion = "rbac.authorization.k8s.io/v1"
                            kind = "Role"
                            metadata = {
                                name = "{}-secret-role".format(oxr.metadata.name)
                                namespace = _ns
                            }
                            rules = [
                                { apiGroups = [""], resources = ["secrets"], verbs = ["get", "list", "watch"] },
                                { apiGroups = ["authorization.k8s.io"], resources = ["selfsubjectrulesreviews"], verbs = ["create"] },
                            ]
                        },

                        # RoleBinding
                        {
                            apiVersion = "rbac.authorization.k8s.io/v1"
                            kind = "RoleBinding"
                            metadata = {
                                name = "{}-secret-rolebinding".format(oxr.metadata.name)
                                namespace = _ns
                            }
                            subjects = [
                                {
                                    kind = "ServiceAccount"
                                    name = "{}-secret-creator".format(oxr.metadata.name)
                                    namespace = _ns
                                }
                            ]
                            roleRef = {
                                apiGroup = "rbac.authorization.k8s.io"
                                kind = "Role"
                                name = "{}-secret-role".format(oxr.metadata.name)
                            }
                        },

                        # SecretStore
                        {
                            apiVersion = "external-secrets.io/v1beta1"
                            kind = "SecretStore"
                            metadata = {
                                name = "{}-secret-store".format(oxr.metadata.name)
                                namespace = _ns
                            }
                            spec = {
                                provider = {
                                    kubernetes = {
                                        auth = { serviceAccount = { name = "{}-secret-creator".format(oxr.metadata.name) } }
                                        remoteNamespace = _ns
                                        server = {
                                            caProvider = { type = "ConfigMap", name = "kube-root-ca.crt", key = "ca.crt" }
                                        }
                                    }
                                }
                            }
                        },

                        # ExternalSecret
                        {
                            apiVersion = "external-secrets.io/v1beta1"
                            kind = "ExternalSecret"
                            metadata = {
                                name = parameters?.backup?.credentialsSecret
                                namespace = _ns
                            }
                            spec = {
                                refreshInterval = "1m"
                                secretStoreRef = {
                                    kind = "SecretStore"
                                    name = "{}-secret-store".format(oxr.metadata.name)
                                }
                                data = [
                                    {
                                        secretKey = "username"
                                        remoteRef = {
                                            key = parameters?.backup?.bucket
                                            property = "username"
                                        }
                                    },
                                    {
                                        secretKey = "password"
                                        remoteRef = {
                                            key = parameters?.backup?.bucket
                                            property = "password"
                                        }
                                    }
                                ]
                                target = {
                                    name = parameters?.backup?.credentialsSecret
                                    creationPolicy = "Owner"
                                    template = {
                                        data = {
                                            "AWS_SECRET_ACCESS_KEY" = "{{ .password }}"
                                            "AWS_ACCESS_KEY_ID"     = "{{ .username }}"
                                        }
                                    }
                                }
                            }
                        },

                    ]
                }
            }
        }
    }

# TODO - clean up , this is not required this can be directly pushed to vault to share with env, keeping it because to make the code compatible with rds

_externalName = ocds["dns-record"]?.Resource?.status?.fqdn or ""

_ExternalService = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-en-svc".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "percona"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Service"
                metadata = {
                    name = parameters?.externalServiceName
                    namespace = parameters?.appNamespace
                }
                spec = {
                    type = "ExternalName"
                    externalName = _externalName
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.ccK8sProviderName
        }
    }
}

_Policy = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "backup-restore-policy"
        }
    }
    spec = {
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.scK8sProviderName
        }
        forProvider = {
            manifest = {
                apiVersion = "kyverno.io/v1"
                kind = "ClusterPolicy"
                metadata = {
                    name = "{}-restore".format(oxr.metadata.name)
                }
                spec = {
                    rules = [
                        {
                            name = "restore-db-backup"
                            match = {
                                "any" = [{
                                    resources = {
                                        kinds = [
                                            "StatefulSet"
                                        ]
                                        namespaces = [
                                            parameters?.scAppNamespace
                                        ]
                                        names = [
                                            "{}-pxc".format(parameters.clusterName)
                                        ]
                                    }
                                }]
                            }
                            preconditions = {
                                "all" = [{
                                    key = """{{ request.object.spec.template.metadata.annotations."utils.mojaloop.io/restore-pvc-name" || ''}}"""
                                    operator = "NotEquals"
                                    value = ""
                                }]
                            }
                            mutate = {
                                patchesJson6902 = """- op: add
  path: /spec/template/spec/initContainers/0
  value:
    name: restore-backup
    image: ${parameters?.backup?.image}
    imagePullPolicy: ${parameters?.backup?.imagePullPolicy}
    command:
      - /bin/sh
    args:
      - -c
      - echo "Backup directory contents:";
        ls -lh /backup;
        if [ -f /backup/xtrabackup.stream ]; then
          echo "MySQL directory contents:";
          ls -lh /datadir;
          if [ -z "$(ls -A /datadir)" ]; then
            echo "Restoring backup...";
            recovery-pvc-donor.sh & RESTORE_SRC_SERVICE=127.0.0.1 recovery-pvc-joiner.sh;
            exit 0;
          else
            echo "MySQL data already exists, skipping restore.";
          fi
        fi
    volumeMounts:
      - name: datadir
        mountPath: /datadir
      - name: vault-keyring-secret
        mountPath: /etc/mysql/vault-keyring-secret
      - name: ssl
        mountPath: /etc/mysql/ssl
      - name: ssl-internal
        mountPath: /etc/mysql/ssl-internal
      - name: backupdir
        mountPath: /backup
- op: add
  path: /spec/template/spec/volumes/-
  value:
    name: backupdir
    persistentVolumeClaim:
      claimName: {{ request.object.spec.template.metadata.annotations."utils.mojaloop.io/restore-pvc-name" }}
"""
                            }
                        }
                    ]
                }
            }
        }
    }
}

_ConsumerAppExternalServices = [
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-en-svc-{}".format(oxr.metadata.name, serviceName)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "mysql-{}".format(serviceName)
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Service"
                    metadata = {
                        name = serviceName
                        namespace = parameters?.appNamespace
                    }
                    spec = {
                        type = "ExternalName"
                        externalName = _externalName
                    }
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.ccK8sProviderName
            }
        }
    } for serviceName in parameters?.consumerAppsExternalServices or []
]

_items += [_Policy, _MysqlCluster, _Secret, _DnsRecord, _s3Bucket, _BucketBackupsBundle, _clientsourceSecret, _ExternalService] + _ConsumerAppCASecrets + _ConsumerAppExternalServices
dxr = {
    **oxr
}
items = _items + [dxr]
