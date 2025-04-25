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
        name = "{}-ss".format(oxr.metadata.name)
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
                    name = "{}-db".format(oxr.metadata.name)
                    namespace = parameters.clusterName
                }
                spec = {
                    crVersion = parameters?.mysql?.crVersion
                    allowUnsafeConfigurations = True
                    imagePullPolicy = "IfNotPresent"
                    pxc = {
                            size = parameters?.mysql?.pxc?.replicas
                            image = parameters?.mysql?.pxc?.image
                            affinity = {
                                antiAffinityTopologyKey = "kubernetes.io/hostname"
                            }
                            podDisruptionBudget = {
                               maxUnavailable = 1
                            }

                            gracePeriod = 600

                            volumeSpec = {
                                accessModes = [
                                    "ReadWriteOnce"
                                ]
                                persistentVolumeClaim = {
                                    resources = {
                                        requests =  {
                                            storage = parameters?.mysql?.pxc?.storageSize
                                        }
                                    }
                                }
                            }

                            resources = {
                                requests =  {
                                    cpu = parameters?.mysql?.pxc?.resources?.requests?.cpu
                                    memory = parameters?.mysql?.pxc?.resources?.requests?.memory
                                }
                                limits = {
                                    cpu = parameters?.mysql?.pxc?.resources?.limits?.cpu
                                    memory = parameters?.mysql?.pxc?.resources?.limits?.memory
                                }
                            }

                            configuration = parameters?.mysql?.pxc?.configuration
                        }
                    haproxy = {
                        enabled = True
                        size = parameters?.mysql?.haproxy?.replicas
                        image = parameters?.mysql?.haproxy?.image
                        affinity = {
                            antiAffinityTopologyKey = "kubernetes.io/hostname"
                        }
                        podDisruptionBudget = {
                            maxUnavailable = 1
                        }
                        exposePrimary = {
                            enabled = parameters?.mysql?.haproxy?.expose
                        }
                        gracePeriod = 30
                        resources = {
                            requests = {
                                cpu = parameters?.mysql?.haproxy?.resources?.requests?.cpu
                                memory = parameters?.mysql?.haproxy?.resources?.requests?.memory
                            }
                            limit = {
                                cpu = parameters?.mysql?.haproxy?.resources?.limit?.cpu
                                memory = parameters?.mysql?.haproxy?.resources?.limit?.memory
                            }
                        }
                    }
                    logcollector = {
                        enabled = True
                        image = parameters?.mysql?.logcollector?.image
                        resources = {
                            requests = {
                                cpu = parameters?.mysql?.logcollector?.resources?.requests?.cpu
                                memory = parameters?.mysql?.logcollector?.resources?.requests?.memory
                            }

                            limit = {
                                cpu = parameters?.mysql?.logcollector?.resources?.limit?.cpu
                                memory = parameters?.mysql?.logcollector?.resources?.limit?.memory
                            }

                        }
                    }
                    backup = {
                    image = parameters?.mysql?.backup?.image
                    storages = {
                        "s3-backup-storage" = {
                            type = "s3"
                            verifyTLS = parameters?.mysql?.backup?.verifyTLS
                            s3 = {
                                bucket = parameters?.mysql?.backup?.bucket
                                credentialsSecret = parameters?.mysql?.backup?.credentialsSecret
                                region = parameters?.mysql?.backup?.bucketRegion
                            }
                        }
                    }
                    schedule = [
                        {
                            name = parameters?.mysql?.backup?.scheduleName
                            schedule = parameters?.mysql?.backup?.cronScheduleExpression
                            keep = parameters?.mysql?.backup?.backupRetention
                            storageName = "s3-backup-storage"
                        }
                    ]
                }
                }
            }
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
                name = parameters?.mysql?.dbSecret
                namespace = parameters?.clusterName
            }
            destination = {
                name = parameters?.mysql?.dbSecret
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

_items += [_MysqlCluster, _Secret]
dxr = {
    **oxr
}
items = _items + [dxr]
