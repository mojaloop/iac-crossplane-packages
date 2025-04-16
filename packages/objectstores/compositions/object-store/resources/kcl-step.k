# Read the XR and the OCDs
oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

## Adding resources
if parameters?.objectStoreProvider == "ceph":
    _cephBucket = {
      apiVersion = "objectstore.mojaloop.io/v1alpha1"
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
            name              = parameters?.bucketName
            esoPushSecret     = parameters?.ceph?.esoPushSecret
            scNamespace       = parameters?.clusterName
            ccNamespace       = oxr.metadata.namespace if oxr.metadata.namespace else "crossplane-system"
            vaultSecretStore  = parameters?.ceph?.vaultSecretStore
            vaultSecretPath   = parameters?.ceph?.vaultSecretPath
          }
        }
        managementPolicies = spec?.managementPolicies
      }
    }
if parameters?.objectStoreProvider == "s3":
    _providerConfigName = parameters?.s3?.awsProviderName
    _s3Bucket = {
      apiVersion = "aws.mojaloop.io/v1alpha1"
      kind = "XS3Bucket"
      metadata = {
        name        = parameters?.bucketName
      }
      spec = {
        parameters = {
          bucketName           = parameters?.bucketName
          bucketRegion         = parameters?.s3?.bucketRegion
          forceDestroy         = parameters?.s3?.forceDestroy
          deletionPolicy       = parameters?.s3?.deletionPolicy
        }
        providerConfigsRef = {
          awsProviderName = _providerConfigName
        }
        managementPolicies = spec?.managementPolicies
      }
    }

_items += [_cephBucket, _s3Bucket]

dxr = {
    **oxr
}

items = _items + [dxr]
