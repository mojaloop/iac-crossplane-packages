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
        name = "{}-ss".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "mongodbcluster"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "psmdb.percona.com/v1"
                kind = "PerconaServerMongoDB"
                metadata = {
                    name = "{}-mongodb".format(oxr.metadata.name)
                    namespace = parameters.clusterName
                }
                spec = {
                    crVersion = parameters?.crVersion
                    image = parameters?.image
                    imagePullPolicy = parameters?.imagePullPolicy
                    secrets = {
                        users = parameters?.dbSecret
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
                            podDisruptionBudget = {
                                maxUnavailable = parameters?.sharding?.configsvrReplSet?.podDisruptionBudget?.maxUnavailable
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
                            podDisruptionBudget = {
                                maxUnavailable = parameters?.sharding?.mongos?.podDisruptionBudget?.maxUnavailable
                            }
                            expose = {
                                type = parameters?.sharding?.mongos?.expose?.type
                            }
                        }
                    }
                    backup = {
                        enabled = parameters?.backup?.enabled
                        image = parameters?.backup?.image
                        storages = {
                            "s3-backup-storage" = {
                                    type = "s3"
                                    s3 = {
                                        bucket = parameters?.backup?.bucket
                                        credentialsSecret = parameters?.backup?.credentialsSecret
                                        region = parameters?.backup?.region
                                    }
                            }
                        }
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

_items += [_MongodbCluster, _Secret]
dxr = {
    **oxr
}
items = _items + [dxr]
