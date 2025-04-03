# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources
_PGCluster = {
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
                apiVersion = "pgv2.percona.com/v2"
                kind = "PerconaPGCluster"
                metadata = {
                    name = "{}-db".format(oxr.metadata.name)
                    namespace = parameters.clusterName
                }
                spec = {
                    crVersion = parameters?.postgres?.crVersion
                    image = "percona/percona-postgresql-operator:2.5.0-ppg16.4-postgres"
                    postgresVersion = parameters?.postgres?.pgVersion
                    port = 5432
                    imagePullPolicy = "IfNotPresent"
                    openshift = False
                    pause = False
                    standby = {
                        enabled = False
                    }
                    unmanaged = False
                    instances = [
                        {
                            name = parameters?.postgres?.dbName
                            replicas = parameters?.postgres?.replicas
                            affinity = {
                                podAntiAffinity = {
                                    preferredDuringSchedulingIgnoredDuringExecution = [
                                        {
                                            podAffinityTerm = {
                                                labelSelector = {
                                                    matchLabels = {
                                                        "postgres-operator.crunchydata.com/data" = "postgres"
                                                    }
                                                }
                                                topologyKey = "kubernetes.io/hostname"
                                            }
                                            weight = 1
                                        }
                                    ]
                                }
                            }
                            dataVolumeClaimSpec = {
                                accessModes = [
                                    "ReadWriteOnce"
                                ]
                                resources = {
                                    requests = {
                                        storage = parameters?.postgres?.storageSize
                                    }
                                }
                            }
                        }
                    ]
                    users = [
                        {
                            databases = [
                                parameters?.postgres?.dbName
                            ]
                            name = parameters?.postgres?.dbUsername
                            options = "SUPERUSER"
                            password = {
                                type = "ASCII"
                            }
                            secretName = parameters?.postgres?.dbSecret
                        }
                    ]
                    backups = {
                        pgbackrest = {
                            image = "percona/percona-postgresql-operator:2.5.0-ppg16.4-pgbackrest2.53-1"
                            repos = [
                                {
                                    name = "repo2"
                                    volume = {
                                        volumeClaimSpec = {
                                            accessModes = [
                                                "ReadWriteOnce"
                                            ]
                                            resources = {
                                                requests = {
                                                    storage = "1Gi"
                                                }
                                            }
                                        }
                                    }
                                }
                            ]
                        }
                    }
                    proxy = {
                        pgBouncer = {
                            image = "percona/percona-postgresql-operator:2.5.0-ppg16.4-pgbouncer1.23.1"
                            replicas = 1
                            port = 5432
                            affinity = {
                                podAntiAffinity = {
                                    preferredDuringSchedulingIgnoredDuringExecution = [
                                        {
                                            podAffinityTerm = {
                                                labelSelector = {
                                                    matchLabels = {
                                                        "postgres-operator.crunchydata.com/role" = "pgbouncer"
                                                    }
                                                }
                                                topologyKey = "kubernetes.io/hostname"
                                            }
                                            weight = 1
                                        }
                                    ]
                                }
                            }
                            config = {
                                global = {
                                    pool_mode = "transaction"
                                    query_wait_timeout = "600"
                                    max_prepared_statements = "1"
                                }
                            }
                            exposeSuperusers = True
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
            name = "{}-en-svc".format(oxr.metadata.name)
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
                name = spec.providerConfigsRef.scK8sProviderName
            }
        }
    }

# _PushSecret = {
#     apiVersion = "kubernetes.crossplane.io/v1alpha2"
#     kind = "Object"
#     metadata = {
#         name = "{}-push-secret".format(oxr.metadata.name)
#         annotations = {
#             "krm.kcl.dev/composition-resource-name": "push-secret"
#         }
#     }
#     spec = {
#         forProvider = {
#             manifest = {
#                 apiVersion = "external-secrets.io/v1alpha1"
#                 kind = "PushSecret"
#                 metadata = {
#                     name = "{}-pushsecret".format(oxr.metadata.name)
#                     namespace = parameters?.appNamespace
#                 }
#                 spec = {
#                     secretStoreRefs = [
#                         {
#                             name = "vault-secret-store"
#                             kind = "ClusterSecretStore"
#                         }
#                     ]
#                     selector = {
#                         secret = {
#                             name = "{}-secret".format(oxr.metadata.name)
#                         }
#                     }
#                     data = [
#                     ]
#                 }
#             }
#         }
#         managementPolicies = spec.managementPolicies
#         providerConfigRef = {
#             name = spec.providerConfigsRef.ccK8sProviderName
#         }
#     }
# }
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
                name = parameters?.postgres?.dbSecret
                namespace = parameters?.clusterName
            }
            destination = {
                name = parameters?.postgres?.dbSecret
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

_items += [_PGCluster, _Secret, _LBService, _HeadlessService, _Endpoint]
dxr = {
    **oxr
}
items = _items + [dxr]
