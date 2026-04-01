# Read the XR and OCDs
oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

## Route based on objectStoreProvider
if parameters?.objectStoreProvider == "ceph":
    _cephUser = {
      apiVersion = "objectstore.mojaloop.io/v1alpha1"
      kind = "XCephBucketUser"
      metadata = {
        name = parameters?.userName
      }
      spec = {
        parameters = {
          userName              = parameters?.userName
          displayName           = parameters?.displayName
          namespaceRook         = parameters?.ceph?.rookNamespace or "rook-ceph"
          storeName             = parameters?.ceph?.storeName or "default"
          operationMask         = parameters?.ceph?.operationMask or ["read", "write", "delete"]
          namespaceCeph         = parameters?.namespace
          scK8sProviderName     = parameters?.scK8sProviderName
          ccK8sProviderName     = parameters?.ccK8sProviderName
        }
        managementPolicies = spec?.managementPolicies
      }
    }
    _items += [_cephUser]

elif parameters?.objectStoreProvider in ["s3", "aws"]:
    _iamUser = {
      apiVersion = "objectstore.mojaloop.io/v1alpha1"
      kind = "XIAMUser"
      metadata = {
        name = parameters?.userName
      }
      spec = {
        parameters = {
          userName        = parameters?.userName
          displayName     = parameters?.displayName
          namespace       = parameters?.namespace
          awsProviderName = parameters?.awsProviderName
          k8sProviderName = parameters?.ccK8sProviderName
          tags            = parameters?.iam?.tags or []
        }
        managementPolicies = spec?.managementPolicies
      }
    }
    _items += [_iamUser]

# Return the composed resources
dxr = {
    **oxr
}

items = _items + [dxr]
