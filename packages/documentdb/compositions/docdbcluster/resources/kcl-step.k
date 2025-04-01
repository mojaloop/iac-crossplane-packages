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
            namespace = parameters?.dbNamespace
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
            name = "{}-sg".format(oxr.metadata.name)
            namespace = parameters?.dbNamespace
        }
        spec = {
            forProvider = {
                name   = "{}-sng".format(oxr.metadata.name)
                description = "Subnet Group for Doc db {}".format(oxr.metadata.name)
                region = parameters?.documentdb?.region
                subnetIds  = parameters?.documentdb?.subnets
            }

        }
    }
_items += [_SecurityGroup, _SubnetGroup]

print(_items)

dxr = {
    **oxr
}

items = _items + [dxr]