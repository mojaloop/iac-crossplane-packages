# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
_items = []

_sourceSecret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-ss".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "secret-source"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "Secret"
        metadata = {
          name = parameters?.sourceSecret?.name
          namespace = parameters?.sourceSecret?.namespace
        }
      }
    }
    managementPolicies = ["Observe"]
    providerConfigRef = {
      name = spec.providerConfigsRef.k8sProviderName
    }
  }
}

_destinationconfigMap = {
  _rawData = ocds["secret-source"]?.Resource?.status?.atProvider?.manifest?.data
  _secretData = _rawData if _rawData != None else {}

  _cmData = {}
  _cmData = {
    **{
      _mapping.destinationKey: base64.decode(str(_secretData[_mapping.sourceKey])) if _mapping.sourceKey in _secretData else _mapping.sourceKey
      for _mapping in parameters?.keyMappings
    }
  }
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-dcm".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "destination-configmap"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "ConfigMap"
        metadata = {
          name = parameters?.destinationConfigMap?.name
          namespace = parameters?.destinationConfigMap?.namespace
        }
        data = _cmData
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.k8sProviderName
    }
  }
}


_items += [_sourceSecret, _destinationconfigMap]

dxr = {
    **oxr
}

items = _items + [dxr]