# Read the XR and the OCDs
import regex
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources

_SecurityGroup = {
    apiVersion = "ec2.aws.upbound.io/v1beta1"
    kind = "SecurityGroup"
    metadata = {
        name = "{}-sg".format(oxr.metadata.name)
    }
    spec = {
        forProvider = {
            name   = "{}-sg".format(oxr.metadata.name)
            description = "Security Group for Doc db access {}".format(oxr.metadata.name)
            region = parameters?.region
            vpcId  = parameters?.vpcId
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.awsProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}

_SecurityGroupRule = {
    apiVersion = "ec2.aws.upbound.io/v1beta1"
    kind = "SecurityGroupRule"
    metadata = {
        name = "{}-sgrule".format(oxr.metadata.name)
    }
    spec = {
        forProvider = {
            description = "Security Group Rule for Doc db access {}".format(oxr.metadata.name)
            fromPort = parameters?.port
            protocol = "tcp"
            region = parameters?.region
            securityGroupIdSelector = { matchControllerRef = True }
            toPort = parameters?.port
            type = "ingress"
            cidrBlocks = parameters?.vpcCidr.split(",")
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.awsProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}

_SubnetGroup = {
    apiVersion = "rds.aws.upbound.io/v1beta1"
    kind = "SubnetGroup"
    metadata = {
        name = "{}-sng".format(oxr.metadata.name)
    }
    spec = {
        forProvider = {
            description = "Subnet Group for Doc db {}".format(oxr.metadata.name)
            region = parameters?.region
            subnetIds  = parameters?.subnets.split(",")
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.awsProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}

_ClusterParameterGroup = {
    apiVersion = "rds.aws.upbound.io/v1beta1"
    kind = "ClusterParameterGroup"
    metadata = {
        name = "{}-cpg".format(oxr.metadata.name)
    }
    spec = {
        forProvider = {
            description = "Cluster Parameter Group for Doc db {}".format(oxr.metadata.name)
            region = parameters?.region
            family = parameters?.family
            parameter = parameters?.parameter
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.awsProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}

availability_zones = parameters?.azs.split(",")
if regex.search(parameters?.engine, "aurora") == True:
    _dbClusterInstanceClass = ""
else:
    _dbClusterInstanceClass = parameters?.dbClusterInstanceClass

_Cluster = {
    apiVersion = "rds.aws.upbound.io/v1beta1"
    kind = "Cluster"
    metadata = {
        name = "{}-cluster".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "cluster"
        }
    }
    spec = {
        forProvider = {
            allowMajorVersionUpgrade = parameters?.allowMajorVersionUpgrade
            applyImmediately = parameters?.applyImmediately
            availabilityZones = availability_zones
            backupRetentionPeriod = parameters?.backupRetentionPeriod
            databaseName = parameters?.databaseName
            dbClusterParameterGroupNameSelector = { matchControllerRef = True }
            dbClusterInstanceClass = _dbClusterInstanceClass
            dbSubnetGroupName = "{}-sng".format(oxr.metadata.name)
            deletionProtection = parameters?.deletionProtection
            engine = parameters?.engine
            engineVersion = parameters?.engineVersion
            finalSnapshotIdentifier = parameters?.finalSnapshotIdentifier
            masterUsername = parameters?.username
            port = parameters?.port
            preferredBackupWindow = parameters?.preferredBackupWindow
            preferredMaintenanceWindow = parameters?.preferredMaintenanceWindow
            region = parameters?.region
            restoreToPointInTime = parameters?.restoreToPointInTime
            skipFinalSnapshot = parameters?.skipFinalSnapshot
            snapshotIdentifier = parameters?.snapshotIdentifier
            storageEncrypted = parameters?.storageEncrypted
            storageType = parameters?.storageType
            iops = parameters?.iops
            allocatedStorage = parameters?.allocatedStorage
            vpcSecurityGroupIdSelector = { matchControllerRef = True }
            masterPasswordSecretRef = {
                            key = parameters?.passwordSecret?.key
                            name = parameters?.passwordSecret?.name
                            namespace = parameters?.passwordSecret?.namespace
                        }

            }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.awsProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}

instance_count = parameters?.instanceCount

_ClusterInstances = [{
    apiVersion = "rds.aws.upbound.io/v1beta1"
    kind = "ClusterInstance"
    metadata = {
        name = "{}-cluster-instance-{}".format(oxr.metadata.name, i)
    }
    spec = {
        forProvider = {
            applyImmediately = parameters?.applyImmediately
            availabilityZone  = availability_zones[i]
            autoMinorVersionUpgrade = parameters?.autoMinorVersionUpgrade
            clusterIdentifierSelector = { matchControllerRef = True }
            copyTagsToSnapshot = parameters?.copyTagsToSnapshot
            performanceInsightsEnabled = parameters?.enablePerformanceInsights
            engine = parameters?.engine
            instanceClass = parameters?.dbClusterInstanceClass
            preferredMaintenanceWindow = parameters?.preferredMaintenanceWindow
            region = parameters?.region
            }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.awsProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}  for i in range(instance_count)] if instance_count > 0 else []

_externalName = ocds["cluster"]?.Resource?.status?.atProvider?.endpoint or ""

_ExternalService = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-en-svc".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "aws-rdscluster-svc"
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

_ConsumerAppExternalServices = [
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-en-svc-{}".format(oxr.metadata.name, serviceName)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "aws-rdscluster-{}".format(serviceName)
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Service"
                    metadata = {
                        name = serviceName
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
    } for serviceName in parameters?.consumerAppsExternalServices or []
]

_CaBundleRequest = {
    apiVersion = "http.crossplane.io/v1alpha2"
    kind = "Request"
    metadata = {
        name = "download-ca"
        annotations = {
            "krm.kcl.dev/composition-resource-name": "aws-rdscluster-ca"
        }
    }
    spec = {
        forProvider = {
            insecureSkipTLSVerify = True
            waitTimeout = "5m"
            payload = {
                baseUrl = parameters?.caBundleUrl
            }
            mappings = [
                {
                    action = "OBSERVE"
                    method = "GET"
                    url = "(.payload.baseUrl)"
                }
            ]
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProviderConfigName
        }
    }
}

_caBundle  =  ocds["aws-rdscluster-ca"]?.Resource?.status?.response?.body or ""

_ConsumerAppCAConfigMaps = [
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-ca-cm-{}".format(oxr.metadata.name, configMap?.namespace)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "ca-cm-{}".format(configMap?.namespace)
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "ConfigMap"
                    metadata = {
                        name = configMap?.name
                        namespace = configMap?.namespace
                    }
                    spec = {
                        data = {
                            configMap?.key = _caBundle
                        }
                    }
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.ccK8sProviderName
            }
        }
    } for configMap in parameters?.consumerAppsConfigMaps or []
]

_items += [_SecurityGroupRule, _SecurityGroup, _SubnetGroup, _ClusterParameterGroup, _Cluster, _ExternalService , _CaBundleRequest] + _ClusterInstances + _ConsumerAppExternalServices + _ConsumerAppCAConfigMaps

print(_items)

dxr = {
**oxr
}

items = _items + [dxr]
