# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources
if parameters?.dbType == "documentdb":
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
                region = parameters?.documentdb?.region
                vpcId  = parameters?.documentdb?.vpcId
            }
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
                fromPort = parameters?.documentdb?.port
                protocol = "tcp"
                region = parameters?.documentdb?.region
                securityGroupIdSelector = { matchControllerRef = True }
                toPort = parameters?.documentdb?.port
                type = "ingress"
            }
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
                region = parameters?.documentdb?.region
                subnetIds  = parameters?.documentdb?.subnets
            }

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
                region = parameters?.documentdb?.region
                family = parameters?.documentdb?.family
                parameter = parameters?.documentdb?.parameter
            }

        }
    }

    _Cluster = {
        apiVersion = "docdb.aws.upbound.io/v1beta1"
        kind = "Cluster"
        metadata = {
            name = "{}-cluster".format(oxr.metadata.name)
        }
        spec = {
            forProvider = {
                allowMajorVersionUpgrade = parameters?.documentdb?.allowMajorVersionUpgrade
                applyImmediately = parameters?.documentdb?.applyImmediately
                availabilityZones = parameters?.documentdb?.availabilityZones
                backupRetentionPeriod = parameters?.documentdb?.backupRetentionPeriod
                dbClusterParameterGroupNameSelector = { matchControllerRef = True }
                dbSubnetGroupName = "{}-sng".format(oxr.metadata.name)
                deletionProtection = parameters?.documentdb?.deletionProtection
                engine = parameters?.documentdb?.engine
                engineVersion = parameters?.documentdb?.engineVersion
                finalSnapshotIdentifier = parameters?.documentdb?.finalSnapshotIdentifier
                masterUsername = parameters?.documentdb?.username
                port = parameters?.documentdb?.port
                preferredBackupWindow = parameters?.documentdb?.preferredBackupWindow
                preferredMaintenanceWindow = parameters?.documentdb?.preferredMaintenanceWindow
                region = parameters?.documentdb?.region
                restoreToPointInTime = parameters?.documentdb?.restoreToPointInTime
                skipFinalSnapshot = parameters?.documentdb?.skipFinalSnapshot
                snapshotIdentifier = parameters?.documentdb?.snapshotIdentifier
                storageEncrypted = parameters?.documentdb?.storageEncrypted
                storageType = parameters?.documentdb?.storageType
                vpcSecurityGroupIdSelector = { matchControllerRef = True }
                masterPasswordSecretRef = {
                                key = parameters?.documentdb?.passwordSecret?.key
                                name = parameters?.documentdb?.passwordSecret?.name
                                namespace = parameters?.documentdb?.passwordSecret?.namespace
                            }

             }
        }
    }

    instance_count = parameters?.documentdb?.instanceCount

    _ClusterInstances += {
        apiVersion = "docdb.aws.upbound.io/v1beta1"
        kind = "ClusterInstance"
        metadata = {
            name = "{}-cluster-instance-{}".format(oxr.metadata.name, i)
        }
        spec = {
            forProvider = {
                applyImmediately = parameters?.documentdb?.applyImmediately
                autoMinorVersionUpgrade = parameters?.documentdb?.autoMinorVersionUpgrade
                availabilityZone = parameters?.documentdb?.availabilityZone
                clusterIdentifierSelector = { matchControllerRef = True }
                copyTagsToSnapshot = parameters?.documentdb?.copyTagsToSnapshot
                enablePerformanceInsights = parameters?.documentdb?.enablePerformanceInsights
                engine = parameters?.documentdb?.engine
                instanceClass = parameters?.documentdb?.dbClusterInstanceClass
                preferredMaintenanceWindow = parameters?.documentdb?.preferredMaintenanceWindow
                region = parameters?.documentdb?.region
             }
        }
    }  for i in range(instance_count)



_items += [_SecurityGroupRule, _SecurityGroup, _SubnetGroup, _ClusterParameterGroup, _Cluster, _ClusterInstances]

print(_items)

dxr = {
    **oxr
}

items = _items + [dxr]
