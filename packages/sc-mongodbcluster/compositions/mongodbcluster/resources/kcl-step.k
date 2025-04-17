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
            "krm.kcl.dev/composition-resource-name": "percona-sql-db"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "psmdb.percona.com/v1"
                kind = "PerconaServerMongoDB"
                metadata = {
                    name = "{}-db".format(oxr.metadata.name)
                    namespace = parameters.clusterName
                }
                spec = {
                    crVersion = parameters?.mongodb?.crVersion
                    image = parameters?.mongodb?.image
                    imagePullPolicy = parameters?.mongodb?.imagePullPolicy
                    secrets = {
                        users = parameters?.mongodb?.secrets?.users
                    }
                    replsets = [
                        {
                            name = "rs0"
                            size = parameters?.mongodb?.replsets?.size
                            affinity = {
                                antiAffinityTopologyKey = "kubernetes.io/hostname"
                            }
                            expose = {
                                enabled = parameters?.mongodb?.replsets?.expose?.enabled
                                type = parameters?.mongodb?.replsets?.expose?.type
                            }
                            resources = {
                                limits = {
                                    cpu = parameters?.mongodb?.replsets?.resources?.limits?.cpu
                                    memory = parameters?.mongodb?.replsets?.resources?.limits?.memory
                                }
                                requests = {
                                    cpu = parameters?.mongodb?.replsets?.resources?.requests?.cpu
                                    memory = parameters?.mongodb?.replsets?.resources?.requests?.memory
                                }
                            }
                            volumeSpec = {
                                persistentVolumeClaim = {
                                    resources = {
                                        requests = {
                                            storage = parameters?.mongodb?.replsets?.volumeSpec?.persistentVolumeClaim?.resources?.requests?.storage
                                        }
                                    }
                                }
                            }
                        }
                    ]
                    sharding = {
                        enabled = parameters?.mongodb?.sharding?.enabled
                        configsvrReplSet = {
                            size = parameters?.mongodb?.sharding?.configsvrReplSet?.size
                            affinity = {
                                antiAffinityTopologyKey = "kubernetes.io/hostname"
                            }
                            resources = {
                                limits = {
                                    cpu = parameters?.mongodb?.sharding?.configsvrReplSet?.resources?.limits?.cpu
                                    memory = parameters?.mongodb?.sharding?.configsvrReplSet?.resources?.limits?.memory
                                }
                                requests = {
                                    cpu = parameters?.mongodb?.sharding?.configsvrReplSet?.resources?.requests?.cpu
                                    memory = parameters?.mongodb?.sharding?.configsvrReplSet?.resources?.requests?.memory
                                }
                            }
                            podDisruptionBudget = {
                                maxUnavailable = parameters?.mongodb?.sharding?.configsvrReplSet?.podDisruptionBudget?.maxUnavailable
                            }
                            expose = {
                                enabled = parameters?.mongodb?.sharding?.configsvrReplSet?.expose?.enabled
                                type = parameters?.mongodb?.sharding?.configsvrReplSet?.expose?.type
                            }
                            volumeSpec = {
                                persistentVolumeClaim = {
                                    resources = {
                                        requests = {
                                            storage = parameters?.mongodb?.sharding?.configsvrReplSet?.volumeSpec?.persistentVolumeClaim?.resources?.requests?.storage
                                        }
                                    }
                                }
                            }
                        }
                        mongos = {
                            size = parameters?.mongodb?.sharding?.mongos?.size
                            affinity = {
                                antiAffinityTopologyKey = "kubernetes.io/hostname"
                            }
                            resources = {
                                limits = {
                                    cpu = parameters?.mongodb?.sharding?.mongos?.resources?.limits?.cpu
                                    memory = parameters?.mongodb?.sharding?.mongos?.resources?.limits?.memory
                                }
                                requests = {
                                    cpu = parameters?.mongodb?.sharding?.mongos?.resources?.requests?.cpu
                                    memory = parameters?.mongodb?.sharding?.mongos?.resources?.requests?.memory
                                }
                            }
                            podDisruptionBudget = {
                                maxUnavailable = parameters?.mongodb?.sharding?.mongos?.podDisruptionBudget?.maxUnavailable
                            }
                            expose = {
                                type = parameters?.mongodb?.sharding?.mongos?.expose?.type
                            }
                        }
                    }
                    backup = {
                        enabled = parameters?.mongodb?.backup?.enabled
                        image = parameters?.mongodb?.backup?.image
                        pitr = {
                            enabled = parameters?.mongodb?.backup?.pitr?.enabled
                            oplogOnly = parameters?.mongodb?.backup?.pitr?.oplogOnly
                            compressionType = parameters?.mongodb?.backup?.pitr?.compressionType
                            compressionLevel = parameters?.mongodb?.backup?.pitr?.compressionLevel
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


if parameters?.consumerClusterType == "controlcenter":
    _LBService = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-lb-svc".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "percona-db-lb-svc"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Service"
                    metadata = {
                        name = "{}-db".format(oxr.metadata.name)
                        namespace = parameters.clusterName
                    }
                    spec = {
                        allocateLoadBalancerNodePorts = True
                        externalTrafficPolicy = "Cluster"
                        internalTrafficPolicy = "Cluster"
                        ipFamilies = [
                            "IPv4"
                        ]
                        ipFamilyPolicy = "SingleStack"
                        ports = [
                            {
                                name = "mongos"
                                port = 2207
                                protocol = "TCP"
                                targetPort = "mongos"
                            }
                        ]
                        selector = {
                            "postgres-operator.crunchydata.com/cluster" = "{}-db".format(oxr.metadata.name)
                            "postgres-operator.crunchydata.com/role" = "pgbouncer"
                        }
                        sessionAffinity = "None"
                        type = "LoadBalancer"
                    }
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.scK8sProviderName
            }
        }
    }

    _ip = ocds["percona-db-lb-svc"]?.Resource?.status?.atProvider?.manifest?.status?.loadBalancer?.ingress[0]?.ip if ocds["percona-db-lb-svc"]?.Resource?.status?.atProvider?.manifest?.status?.loadBalancer?.ingress else ""
    _HeadlessService = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-en-svc".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "percona-db-hs-svc"
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
                        clusterIP = "None"
                        ports = [
                            {
                                port: 3306
                                protocol: "TCP"
                                targetPort: 3306
                            }
                        ]
                    }
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.ccK8sProviderName
            }
        }
    }

    _Endpoint = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-endpoint".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "percona-db-ep-svc"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    kind: "Endpoints"
                    apiVersion: "v1"
                    metadata: {
                        name = parameters?.externalServiceName
                        namespace = parameters?.appNamespace
                    }
                    subsets: [
                        {
                            addresses: [
                                {ip: _ip}
                            ]
                            ports: [
                                {
                                    port: 3306
                                    protocol: "TCP"
                                    targetPort: 3306
                                }
                            ]
                        }
                    ]
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.ccK8sProviderName
            }
        }
    }

if parameters?.consumerClusterType == "environment":
    _LBService = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-nb-svc".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "percona-db-nb-svc"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    # TODO NB SERVICE
                    apiVersion = "v1"
                    kind = "Service"
                    metadata = {
                        name = "{}-db".format(oxr.metadata.name)
                        namespace = parameters?.clusterName
                    }
                    spec = {
                        type = "ExternalName"
                        externalName = _ip
                        ports = [
                            {
                                port: 3306
                                protocol: "TCP"
                                targetPort: 3306
                            }
                        ]
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
                name = parameters?.mongodb?.dbSecret
                namespace = parameters?.clusterName
            }
            destination = {
                name = parameters?.mongodb?.dbSecret
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

_items += [_MongodbCluster, _Secret, _LBService, _HeadlessService, _Endpoint]
dxr = {
    **oxr
}
items = _items + [dxr]
