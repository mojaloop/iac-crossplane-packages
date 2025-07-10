# Read the XR and the OCDs
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
    apiVersion = "docdb.aws.upbound.io/v1beta1"
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
    apiVersion = "docdb.aws.upbound.io/v1beta1"
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
_Cluster = {
    apiVersion = "docdb.aws.upbound.io/v1beta1"
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
            dbClusterParameterGroupNameSelector = { matchControllerRef = True }
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
    apiVersion = "docdb.aws.upbound.io/v1beta1"
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
            enablePerformanceInsights = parameters?.enablePerformanceInsights
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
            "krm.kcl.dev/composition-resource-name": "aws-docdbcluster-svc"
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
                "krm.kcl.dev/composition-resource-name": "aws-docdbcluster-{}".format(serviceName)
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
    kind = "DisposableRequest"
    metadata = {
        name = "{}-download-ca".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "aws-docdbcluster-ca"
        }
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            url = parameters?.caBundleUrl
            method = "GET"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProviderConfigName
        }
    }
}

_caBundle  =  ocds["aws-docdbcluster-ca"]?.Resource?.status?.response?.body or ""

_ConsumerAppCAConfigMaps = [
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-ca-cm-{}".format(oxr.metadata.name, configMapNs)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "ca-cm-{}".format(configMapNs)
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "ConfigMap"
                    metadata = {
                        name = parameters?.consumerAppsConfigMap?.name
                        namespace = configMapNs
                    }
                    data = {
                        parameters?.consumerAppsConfigMap?.key = _caBundle
                    }
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.ccK8sProviderName
            }
        }
    } for configMapNs in parameters?.consumerAppsConfigMap.namespaces or []
]

_items += [_SecurityGroupRule, _SecurityGroup, _SubnetGroup, _ClusterParameterGroup, _Cluster, _ExternalService, _CaBundleRequest] + _ClusterInstances + _ConsumerAppExternalServices + _ConsumerAppCAConfigMaps

print(_items)

dxr = {
**oxr
}

items = _items + [dxr]
