# Read the XR and the OCDs
oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

## Adding resources
if spec?.objectStoreProvider == "ceph":
    _objectStore = {
      apiVersion = "mojaloop.io/v1alpha1"
      kind = "XCephBucket"
      metadata = {
        name = parameters?.bucketName
      }
      spec = {
        providerConfigsRef = {
          scK8sProviderName = spec?.providerConfigsRef?.scK8sProviderName
          ccK8sProviderName = spec?.providerConfigsRef?.ccK8sProviderName
        }
        parameters = {
          bucket = {
            bucketName               = parameters?.bucketName
            storageClassName         = parameters?.storageClassName
            maxSize                  = parameters?.maxSize
            objectStore_ext_svc_name = parameters?.objectStore_ext_svc_name
          }
          secret = {
            name                  = parameters?.bucketName
            eso_pushsecret        = parameters?.eso_pushsecret
            sc_namespace          = parameters?.Namespace
            cc_namespace          = parameters?.Namespace
            vault_secrestore_name = parameters?.vault_secrestore_name
            vault_secret_path     = parameters?.vault_secret_path
          }
        }
      }
    }
if spec?.objectStoreProvider == "aws":
    _objectStore = {
      apiVersion = "mojaloop.io/v1alpha1"
      kind = "S3Bucket"
      metadata = {
        name        = parameters?.bucketName
      }
      spec = {
        parameters = {
          bucketName           = parameters?.bucketName
          bucketRegion         = parameters?.bucketRegion
          forceDestroy         = parameters?.forceDestroy
          deletionPolicy       = parameters?.deletionPolicy
          destinationNamespace = parameters?.Namespace
          providerConfigName   = spec?.providerConfigsRef?.awsProviderName
          }
        }
    }
_items += [_objectStore]

dxr = {
    **oxr
}

items = _items + [dxr]