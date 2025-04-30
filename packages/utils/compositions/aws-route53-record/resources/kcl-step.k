# Read the XR and the OCDs
import regex
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources

_Record = {
    apiVersion = "route53.aws.upbound.io/v1beta2"
    kind = "Record"
    metadata = {
        name = "{}-record".format(oxr.metadata.name)
    }
    spec = {
        forProvider = {
            name   = "{}-sg".format(oxr.metadata.name)
            region = parameters?.region
            ttl  = parameters?.ttl
            type = parameters?.type
            records = parameters?.records
            zoneId  = parameters?.zoneId
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.awsProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}

_items += [_Record]

print(_items)

dxr = {
**oxr
}

items = _items + [dxr]