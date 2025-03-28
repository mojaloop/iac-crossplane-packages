# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources
if parameters?.dbType == "postgres":
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
                        namespace = parameters?.dbNamespace
                    }
                    spec = {
                        crVersion = parameters?.postgres?.crVersion
                        image = parameters?.postgres?.image
                        postgresVersion = parameters?.postgres?.pgVersion
                        port = 5432
                        imagePullPolicy = "Always"
                        openshift = False
                        pause = False
                        standby = {
                            enabled = False
                        }
                        unmanaged = False
                        instances = [
                            {
                                name = "{}-db".format(oxr.metadata.name)
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
                                    "{}-db".format(oxr.metadata.name)
                                ]
                                name = "admin"
                                options = "SUPERUSER"
                                password = {
                                    type = "ASCII"
                                }
                                secretName = "{}-secret".format(oxr.metadata.name)
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
                    namespace = parameters?.dbNamespace
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
_ExternalNameService = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-en-svc".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "percona-db-en-svc"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Service"
                metadata = {
                    name = "{}-db".format(oxr.metadata.name)
                    namespace = parameters?.secretNamespace
                }
                spec = {
                    type = "ExternalName"
                    externalName = _ip
                    ports = {
                      port = [
                        3306
                      ]
                      protocol = "TCP"
                      targetPort = 3306
                    }
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.ccK8sProviderName
        }
    }
}

_Secret = {
    apiVersion = "infitx.org/v1alpha1"
    kind = "XObjectSyncer"
    metadata = {
        name = "{}-secret".format(oxr.metadata.name)
    }
    spec = {
        parameters = {
            objectType = "Secret"
            source = {
                name = "{}-secret".format(oxr.metadata.name)
                namespace = parameters?.dbNamespace
            }
            destination = {
                namespace = parameters?.secretNamespace
                name = "{}-secret".format(oxr.metadata.name)
            }
        }
        providerConfigsRef = {
            sourceK8sProviderName = spec?.providerConfigsRef?.scK8sProviderName
            destinationK8sProviderName = spec?.providerConfigsRef?.ccK8sProviderName
        }
        managementPolicies = spec?.managementPolicies
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
#                     namespace = parameters?.secretNamespace
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
_items += [_PGCluster, _Secret, _LBService, _ExternalNameService]
dxr = {
    **oxr
}
items = _items + [dxr]
