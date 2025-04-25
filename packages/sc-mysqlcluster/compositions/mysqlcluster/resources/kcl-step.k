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
                    crVersion = parameters?.crVersion
                    allowUnsafeConfigurations = True
                    imagePullPolicy = "IfNotPresent"
                    pxc = {
                            size = parameters?.pxc?.replicas
                            image = parameters?.pxc?.image
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
                        }
                    haproxy = {
                        enabled = True
                        size = parameters?.haproxy?.replicas
                        image = parameters?.haproxy?.image
                        affinity = {
                            antiAffinityTopologyKey = "kubernetes.io/hostname"
                        }
                        podDisruptionBudget = {
                            maxUnavailable = 1
                        }
                        exposePrimary = {
                            enabled = parameters?.haproxy?.expose
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
                    }
                    logcollector = {
                        enabled = True
                        image = parameters?.logcollector?.image
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
                namespace = parameters?.clusterName
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

_items += [_MysqlCluster, _Secret]
dxr = {
    **oxr
}
items = _items + [dxr]
