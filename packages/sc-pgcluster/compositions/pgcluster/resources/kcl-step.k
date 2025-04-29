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
                    crVersion = parameters?.crVersion
                    image = parameters?.image #"percona/percona-postgresql-operator:2.5.0-ppg16.4-postgres"
                    postgresVersion = parameters?.pgVersion
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
                            name = parameters?.dbName
                            replicas = parameters?.replicas
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
                                        storage = parameters?.storageSize
                                    }
                                }
                            }

                            resources = {
                                limits = {
                                    cpu = parameters?.resources?.limits?.cpu
                                    memory = parameters?.resources?.limits?.memory
                                }
                                requests = {
                                    cpu = parameters?.resources?.requests?.cpu
                                    memory = parameters?.resources?.requests?.memory
                                }
                            }
                            tolerations = parameters?.tolerations
                            priorityClassName = parameters?.priorityClassName

                        }
                    ]
                    users = [
                        {
                            databases = [
                                parameters?.dbName
                            ]
                            name = parameters?.dbUsername
                            options = "SUPERUSER"
                            password = {
                                type = "ASCII"
                            }
                            secretName = parameters?.dbSecret
                        }
                    ]
                    backups = {
                        pgbackrest = {
                            image =  parameters?.backup?.image #"percona/percona-postgresql-operator:2.5.0-ppg16.4-pgbackrest2.53-1"
                            repos = [
                                {
                                    name = "repo2"
                                    s3 = {
                                        endpoint =  parameters?.backup?.objectStoreEndpoint
                                        bucket   = parameters?.backup?.bucket
                                        region   = parameters?.backup?.bucketRegion
                                    }
                                    schedules = {
                                        full = parameters?.backup?.fullBackupCronSchedule
                                        differential = parameters?.backup?.differentialBackupCronSchedule
                                    }
                                }
                            ]
                        }
                    }
                    proxy = {
                        pgBouncer = {
                            image = parameters?.proxy?.pgBouncer?.image #"percona/percona-postgresql-operator:2.5.0-ppg16.4-pgbouncer1.23.1"
                            replicas = parameters?.proxy?.pgBouncer?.replicas
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
                                global = parameters?.proxy?.pgBouncer?.globalConfig
                            }
                            exposeSuperusers = parameters?.proxy?.pgBouncer?.exposeSuperusers
                            resources = {
                                limits = {
                                    cpu = parameters?.proxy?.pgBouncer?.resources?.limits?.cpu
                                    memory = parameters?.proxy?.pgBouncer?.resources?.limits?.memory
                                }
                                request = {
                                    cpu = parameters?.proxy?.pgBouncer?.resources?.request?.cpu
                                    memory = parameters?.proxy?.pgBouncer?.resources?.request?.memory
                                }
                            }
                            expose = {
                                annotations = {
                                    annotation = parameters?.proxy?.pgBouncer?.expose?.annotations?["annotation"]
                                }
                                labels = {
                                    label = parameters?.proxy?.pgBouncer?.expose?.labels?["label"]
                                }
                                type = parameters?.proxy?.pgBouncer?.expose?.type
                                loadBalancerSourceRanges = parameters?.proxy?.pgBouncer?.expose?.loadBalancerSourceRanges
                            }
                            tolerations = parameters?.proxy?.pgBouncer?.tolerations
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



_ip = ocds["percona-sql-db"]?.Resource?.status?.atProvider?.manifest?.status?.host if ocds["percona-sql-db"]?.Resource?.status?.atProvider?.manifest?.status?.host else ""
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

_items += [_PGCluster, _Secret, _HeadlessService, _Endpoint]
dxr = {
    **oxr
}
items = _items + [dxr]
