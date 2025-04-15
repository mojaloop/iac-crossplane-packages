# Read the XR and the OCDs
import regex
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources
if parameters?.dbType == "rds":
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
                region = parameters?.rds?.region
                vpcId  = parameters?.rds?.vpcId
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
                fromPort = parameters?.rds?.port
                protocol = "tcp"
                region = parameters?.rds?.region
                securityGroupIdSelector = { matchControllerRef = True }
                toPort = parameters?.rds?.port
                type = "ingress"
                cidrBlocks = parameters?.rds?.vpcCidr.split(",")
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
                region = parameters?.rds?.region
                subnetIds  = parameters?.rds?.subnets.split(",")
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
                region = parameters?.rds?.region
                family = parameters?.rds?.family
                parameter = parameters?.rds?.parameter
            }
            providerConfigRef = {
                name = spec?.providerConfigsRef?.awsProviderConfigName
            }
            managementPolicies = spec.managementPolicies
        }
    }


    if regex.search(parameters?.rds?.engine, "aurora") == True:
       _dbClusterInstanceClass = ""
    else:
        _dbClusterInstanceClass = parameters?.rds?.dbClusterInstanceClass

    _Cluster = {
        apiVersion = "rds.aws.upbound.io/v1beta1"
        kind = "Cluster"
        metadata = {
            name = "{}-cluster".format(oxr.metadata.name)
        }
        spec = {
            forProvider = {
                allowMajorVersionUpgrade = parameters?.rds?.allowMajorVersionUpgrade
                applyImmediately = parameters?.rds?.applyImmediately
                backupRetentionPeriod = parameters?.rds?.backupRetentionPeriod
                dbClusterParameterGroupNameSelector = { matchControllerRef = True }
                dbClusterInstanceClass = _dbClusterInstanceClass
                dbSubnetGroupName = "{}-sng".format(oxr.metadata.name)
                deletionProtection = parameters?.rds?.deletionProtection
                engine = parameters?.rds?.engine
                engineVersion = parameters?.rds?.engineVersion
                finalSnapshotIdentifier = parameters?.rds?.finalSnapshotIdentifier
                masterUsername = parameters?.rds?.username
                port = parameters?.rds?.port
                preferredBackupWindow = parameters?.rds?.preferredBackupWindow
                preferredMaintenanceWindow = parameters?.rds?.preferredMaintenanceWindow
                region = parameters?.rds?.region
                restoreToPointInTime = parameters?.rds?.restoreToPointInTime
                skipFinalSnapshot = parameters?.rds?.skipFinalSnapshot
                snapshotIdentifier = parameters?.rds?.snapshotIdentifier
                storageEncrypted = parameters?.rds?.storageEncrypted
                storageType = parameters?.rds?.storageType
                iops = parameters?.rds?.iops
                allocatedStorage = parameters?.rds?.allocatedStorage
                vpcSecurityGroupIdSelector = { matchControllerRef = True }
                masterPasswordSecretRef = {
                                key = parameters?.rds?.passwordSecret?.key
                                name = parameters?.rds?.passwordSecret?.name
                                namespace = parameters?.rds?.passwordSecret?.namespace
                            }

             }
            providerConfigRef = {
                name = spec?.providerConfigsRef?.awsProviderConfigName
            }
            managementPolicies = spec.managementPolicies
        }
    }

    instance_count = parameters?.rds?.instanceCount

    _ClusterInstances = [{
        apiVersion = "rds.aws.upbound.io/v1beta1"
        kind = "ClusterInstance"
        metadata = {
            name = "{}-cluster-instance-{}".format(oxr.metadata.name, i)
        }
        spec = {
            forProvider = {
                applyImmediately = parameters?.rds?.applyImmediately
                autoMinorVersionUpgrade = parameters?.rds?.autoMinorVersionUpgrade
                clusterIdentifierSelector = { matchControllerRef = True }
                copyTagsToSnapshot = parameters?.rds?.copyTagsToSnapshot
                enablePerformanceInsights = parameters?.rds?.enablePerformanceInsights
                engine = parameters?.rds?.engine
                instanceClass = parameters?.rds?.dbClusterInstanceClass
                preferredMaintenanceWindow = parameters?.rds?.preferredMaintenanceWindow
                region = parameters?.rds?.region
             }
            providerConfigRef = {
                name = spec?.providerConfigsRef?.awsProviderConfigName
            }
            managementPolicies = spec.managementPolicies
        }
    }  for i in range(instance_count)] if instance_count > 0 else []



_items += [_SecurityGroupRule, _SecurityGroup, _SubnetGroup, _ClusterParameterGroup, _Cluster] + _ClusterInstances

print(_items)

dxr = {
    **oxr
}

items = _items + [dxr]
