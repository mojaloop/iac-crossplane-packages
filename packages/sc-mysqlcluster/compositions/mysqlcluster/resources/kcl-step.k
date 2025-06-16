# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
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
                    namespace = parameters.appNamespace
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
                            limit = {
                                cpu = parameters?.haproxy?.resources?.limit?.cpu
                                memory = parameters?.haproxy?.resources?.limit?.memory
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

                            limit = {
                                cpu = parameters?.logcollector?.resources?.limit?.cpu
                                memory = parameters?.logcollector?.resources?.limit?.memory
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
                    schedule = [
                        {
                            name = parameters?.backup?.scheduleName
                            schedule = parameters?.backup?.cronScheduleExpression
                            keep = parameters?.backup?.backupRetention
                            storageName = "s3-backup-storage"
                        }
                    ]
                }
                }
            }
        }
        readiness = {
            policy = "DeriveFromCelQuery"
            celQuery = '"status" in object && "conditions" in object.status && object.status.conditions.exists(c, c.type == "ready" && c.status == "True" )'
        }
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
                name = parameters?.dbSecret
                namespace = parameters?.appNamespace
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
            "krm.kcl.dev/composition-resource-name": "pxc-mysqlcluster-svc"
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
                                parameters?.appNamespace
                            ]
                            selector = {
                                matchLabels = {
                                    "app.kubernetes.io/component" = "pxc"
                                    "app.kubernetes.io/managed-by" = "percona-xtradb-cluster-operator"
                                }
                            }
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
                    patchesJson6902 = """
- op: add
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
          if [ ! -d /datadir/mysql ]; then
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

_items += [_Policy, _MysqlCluster, _Secret, _DnsRecord, _ExternalService]
dxr = {
    **oxr
}
items = _items + [dxr]
