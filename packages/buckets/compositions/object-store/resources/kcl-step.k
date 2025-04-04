# Read the XR and the OCDs
oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

## Adding resources
if parameters?.objectStoreProvider == "ceph":
    _objectStore = {
      apiVersion = "mojaloop.io/v1alpha1"
      kind = "XCephBucket"
      metadata = {
        name = parameters?.bucketName
      }
      spec = {
        providerConfigsRef = {
          scK8sProviderName = parameters?.ceph?.scK8sProviderName
          ccK8sProviderName = parameters?.ceph?.ccK8sProviderName
        }
        parameters = {
          bucket = {
            bucketName               = parameters?.bucketName
            storageClassName         = parameters?.ceph?.storageClassName
            maxSize                  = parameters?.ceph?.maxSize
          }
          secret = {
            name                  = parameters?.bucketName
            esoPushSecret        = parameters?.ceph?.esoPushSecret
            scNamespace          = parameters?.clusterName
            ccNamespace          = parameters?.Namespace
            vaultSecretStore = parameters?.ceph?.vaultSecretStore
            vaultSecretPath     = parameters?.ceph?.vaultSecretPath
          }
        }
      }
    }
if parameters?.objectStoreProvider == "s3":
    _objectStore = {
      apiVersion = "mojaloop.io/v1alpha1"
      kind = "S3Bucket"
      metadata = {
        name        = parameters?.bucketName
      }
      spec = {
        parameters = {
          bucketName           = parameters?.bucketName
          bucketRegion         = parameters?.s3?.bucketRegion
          forceDestroy         = parameters?.s3?.forceDestroy
          deletionPolicy       = parameters?.s3?.deletionPolicy
          providerConfigName   = parameters?.s3?.awsProviderName
          destinationNamespace = parameters?.Namespace
          }
        }
    }
_items += [_objectStore]

dxr = {
    **oxr
}

items = _items + [dxr]
