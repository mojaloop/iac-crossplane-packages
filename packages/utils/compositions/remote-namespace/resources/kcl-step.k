# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources
_namespaceObject = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-ns".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "destination-namespace"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Namespace"
                metadata = {
                    name = parameters.name
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.destinationK8sProviderName
        }
    }
}

_items += [_namespaceObject]

dxr = {
    **oxr
}

items = _items + [dxr]
