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
                            image = "percona/percona-xtradb-cluster:{}".format(parameters?.mysql?.pxc?.imageVersion)
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
                                requests = parameters?.mysql?.pxc?.resources?.requests
                                limit  = parameters?.mysql?.pxc?.resources?.limit
                            }

                            configuration = parameters?.mysql?.pxc?.configuration
                        }
                    haproxy = {
                        enabled = True
                        size = parameters?.mysql?.haproxy?.replicas
                        image = "percona/haproxy:{}".format(parameters?.mysql?.haproxy?.imageVersion)
                        affinity = {
                            antiAffinityTopologyKey = "kubernetes.io/hostname"
                        }
                        podDisruptionBudget = {
                            maxUnavailable = 1
                        }
                        gracePeriod = 30
                        resources = {
                            requests = parameters?.mysql?.haproxy?.resources?.requests
                            limit  = parameters?.mysql?.haproxy?.resources?.limit
                        }
                    }
                    logcollector = {
                        enabled = True
                        image = "percona/percona-xtradb-cluster-operator:{}".format(parameters?.mysql?.logcollector?.imageVersion)
                        resources = {
                            requests = parameters?.mysql?.logcollector?.resources?.requests
                            limit  = parameters?.mysql?.logcollector?.resources?.limit
                        }
                    }
                    backup = {
                    image = "percona/percona-xtradb-cluster-operator:{}".format(parameters?.mysql?.backup?.imageVersion)
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
                                name = "pgbouncer"
                                port = 5432
                                protocol = "TCP"
                                targetPort = "pgbouncer"
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
                                port: 5432
                                protocol: "TCP"
                                targetPort: 5432
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
                                    port: 5432
                                    protocol: "TCP"
                                    targetPort: 5432
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

_items += [_MysqlCluster, _Secret, _LBService, _HeadlessService, _Endpoint]
dxr = {
    **oxr
}
items = _items + [dxr]
