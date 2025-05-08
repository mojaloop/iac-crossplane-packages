# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources
_MongodbCluster = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-psmdb".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "percona-mongodb-cluster"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "psmdb.percona.com/v1"
                kind = "PerconaServerMongoDB"
                metadata = {
                    name = parameters.clusterName
                    namespace = parameters.appNamespace
                }
                spec = {
                    crVersion = parameters?.crVersion
                    image = parameters?.image
                    imagePullPolicy = parameters?.imagePullPolicy
                    secrets = {
                        users = parameters?.dbSecret
                    }
                    unsafeFlags = {
                        tls = True
                        replsetSize = True
                        mongosSize = True
                        terminationGracePeriod = True
                        backupIfUnhealthy = True
                    }
                    replsets = [
                        {
                            name = "rs0"
                            size = parameters?.replsets?.size
                            affinity = {
                                antiAffinityTopologyKey = "kubernetes.io/hostname"
                            }
                            expose = {
                                enabled = parameters?.replsets?.expose?.enabled
                                type = parameters?.replsets?.expose?.type
                            }
                            resources = {
                                limits = {
                                    cpu = parameters?.replsets?.resources?.limits?.cpu
                                    memory = parameters?.replsets?.resources?.limits?.memory
                                }
                                requests = {
                                    cpu = parameters?.replsets?.resources?.requests?.cpu
                                    memory = parameters?.replsets?.resources?.requests?.memory
                                }
                            }
                            volumeSpec = {
                                persistentVolumeClaim = {
                                    resources = {
                                        requests = {
                                            storage = parameters?.replsets?.volumeSpec?.persistentVolumeClaim?.resources?.requests?.storage
                                        }
                                    }
                                }
                            }

                            podDisruptionBudget = {
                                maxUnavailable = parameters?.sharding?.mongos?.podDisruptionBudget?.maxUnavailable
                                minAvailable = parameters?.sharding?.mongos?.podDisruptionBudget?.minAvailable
                            } if parameters?.sharding?.mongos?.podDisruptionBudget else {}

                            priorityClassName = parameters?.sharding?.mongos?.priorityClassName

                            tolerations = parameters?.sharding?.mongos?.tolerations
                        }
                    ]
                    sharding = {
                        enabled = parameters?.sharding?.enabled
                        configsvrReplSet = {
                            size = parameters?.sharding?.configsvrReplSet?.size
                            affinity = {
                                antiAffinityTopologyKey = "kubernetes.io/hostname"
                            }
                            resources = {
                                limits = {
                                    cpu = parameters?.sharding?.configsvrReplSet?.resources?.limits?.cpu
                                    memory = parameters?.sharding?.configsvrReplSet?.resources?.limits?.memory
                                }
                                requests = {
                                    cpu = parameters?.sharding?.configsvrReplSet?.resources?.requests?.cpu
                                    memory = parameters?.sharding?.configsvrReplSet?.resources?.requests?.memory
                                }
                            }

                            expose = {
                                enabled = parameters?.sharding?.configsvrReplSet?.expose?.enabled
                                type = parameters?.sharding?.configsvrReplSet?.expose?.type
                            }
                            volumeSpec = {
                                persistentVolumeClaim = {
                                    resources = {
                                        requests = {
                                            storage = parameters?.sharding?.configsvrReplSet?.volumeSpec?.persistentVolumeClaim?.resources?.requests?.storage
                                        }
                                    }
                                }
                            }
                            podDisruptionBudget = {
                                maxUnavailable = parameters?.sharding?.configsvrReplSet?.podDisruptionBudget?.maxUnavailable
                                minAvailable = parameters?.sharding?.configsvrReplSet?.podDisruptionBudget?.minAvailable
                            } if parameters?.sharding?.configsvrReplSet?.podDisruptionBudget else {}

                            priorityClassName = parameters?.sharding?.configsvrReplSet?.priorityClassName

                            tolerations = parameters?.sharding?.configsvrReplSet?.tolerations
                        }
                        mongos = {
                            size = parameters?.sharding?.mongos?.size
                            affinity = {
                                antiAffinityTopologyKey = "kubernetes.io/hostname"
                            }
                            resources = {
                                limits = {
                                    cpu = parameters?.sharding?.mongos?.resources?.limits?.cpu
                                    memory = parameters?.sharding?.mongos?.resources?.limits?.memory
                                }
                                requests = {
                                    cpu = parameters?.sharding?.mongos?.resources?.requests?.cpu
                                    memory = parameters?.sharding?.mongos?.resources?.requests?.memory
                                }
                            }

                            expose = {
                                type = parameters?.sharding?.mongos?.expose?.type
                            }
                            podDisruptionBudget = {
                                maxUnavailable = parameters?.sharding?.mongos?.podDisruptionBudget?.maxUnavailable
                                minAvailable = parameters?.sharding?.mongos?.podDisruptionBudget?.minAvailable
                            } if parameters?.sharding?.mongos?.podDisruptionBudget else {}

                            priorityClassName = parameters?.sharding?.mongos?.priorityClassName

                            tolerations = parameters?.sharding?.mongos?.tolerations

                        }
                    }
                    backup = {
                        enabled = parameters?.backup?.enabled
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
                        tasks = [
                          {
                                enabled = parameters?.backup?.scheduleEnabled
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

_ip = [ocds["percona-mongodb-cluster"]?.Resource?.status?.atProvider?.manifest?.status?.host] if ocds["percona-mongodb-cluster"]?.Resource?.status?.atProvider?.manifest?.status?.host else []

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
            "krm.kcl.dev/composition-resource-name": "percona-mongodb-svc"
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


_items += [_MongodbCluster, _Secret, _DnsRecord, _ExternalService]
dxr = {
    **oxr
}
items = _items + [dxr]
