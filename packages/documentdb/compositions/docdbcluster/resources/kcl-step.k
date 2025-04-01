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


_items += [_SecurityGroup, _SubnetGroup, _ClusterParameterGroup, _Cluster]

print(_items)

dxr = {
    **oxr
}

items = _items + [dxr]
