import regex

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
          ccK8sProviderName = parameters?.ccK8sProviderName
        }
        parameters = {
          bucket = {
            bucketName               = regex.replace(parameters?.bucketName, "\.", "-")
            storageClassName         = parameters?.ceph?.storageClassName
            maxSize                  = parameters?.ceph?.maxSize
          }
          secret = {
            name              = parameters?.bucketName
            esoPushSecret     = parameters?.esoPushSecret
            scNamespace       = parameters?.clusterName
            ccNamespace       = parameters?.namespace
            vaultSecretStore  = parameters?.vaultSecretStore
            vaultSecretPath   = parameters?.vaultSecretPath
          }
        }
        managementPolicies = spec?.managementPolicies
      }
    }
if parameters?.objectStoreProvider == "s3":
    _awsProviderName = parameters?.s3?.awsProviderName
    _k8sProviderName = parameters?.ccK8sProviderName
    _s3Bucket = {
      apiVersion = "aws.mojaloop.io/v1alpha1"
      kind = "XS3Bucket"
      metadata = {
        name        = parameters?.bucketName
      }
      spec = {
        parameters = {
          bucket = {
          bucketName           = regex.replace(parameters?.bucketName, "\.", "-")
          bucketRegion         = parameters?.s3?.bucketRegion
          forceDestroy         = parameters?.s3?.forceDestroy
          deletionPolicy       = parameters?.s3?.deletionPolicy
          }
        secret = {
          name             = parameters?.bucketName
          namespace        = parameters?.namespace
          esoPushSecret    = parameters?.esoPushSecret
          vaultSecretStore = parameters?.vaultSecretStore
          vaultSecretPath  = parameters?.vaultSecretPath
          }
        }
        providerConfigsRef = {
          awsProviderName = _awsProviderName
          k8sProviderName = _k8sProviderName
        }
        managementPolicies = spec?.managementPolicies
      }
    }

_items += [_cephBucket, _s3Bucket]

dxr = {
    **oxr
}

items = _items + [dxr]
