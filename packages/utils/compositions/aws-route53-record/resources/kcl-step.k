# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources

_fqdn  = ocds["record"]?.Resource?.status?.atProvider?.fqdn or ""
_Record = {
    apiVersion = "route53.aws.upbound.io/v1beta2"
    kind = "Record"
    metadata = {
        name = "{}-record".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "record"
        }
    }
    spec = {
        forProvider = {
            name   = parameters?.name
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
    status = {
        fqdn = _fqdn
    }
}

items = _items + [dxr]