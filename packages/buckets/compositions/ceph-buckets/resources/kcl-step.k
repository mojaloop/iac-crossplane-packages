# Read the XR and the OCDs
oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

## Adding resources
_cephBucket= {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-bucket".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "ceph-bucket"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "objectbucket.io/v1alpha1"
        kind = "ObjectBucketClaim"
        metadata = {
          name = parameters.bucket.bucketName
          namespace = parameters.secret.sc_namespace
        }
        spec = {
          bucketName         = parameters.bucket.bucketName
          storageClassName   = parameters.bucket.storageClassName
          additionalConfig   = {
            maxSize    = parameters.bucket.maxSize
            maxObjects = parameters.bucket.maxObjects
          }
        }
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}

_sourceSecret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-ss".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "source-secret"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "Secret"
        metadata = {
          name = parameters.bucket.bucketName
          namespace = parameters.secret.sc_namespace
        }
      }
    }
    managementPolicies = ["Observe"]
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}

_destinationSecret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-ds".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "destination-secret"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "Secret"
        metadata = {
          name = parameters.bucket.bucketName
          namespace = parameters.secret.cc_namespace
        }
        # Get data and type from the source secret's status
        data = ocds["source-secret"]?.Resource?.status?.atProvider?.manifest?.data
        type = ocds["source-secret"]?.Resource?.status?.atProvider?.manifest?.type
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.ccK8sProviderName
    }
  }
}

if parameters?.secret?.eso_pushsecret:
    _pushSecret = {
      apiVersion = "kubernetes.crossplane.io/v1alpha2"
      kind = "Object"
      metadata = {
        name = "{}-push-secret".format(oxr.metadata.name)
        annotations = {
          "krm.kcl.dev/composition-resource-name": "push-secret"
        }
      }
      spec = {
        forProvider = {
          manifest = {
            apiVersion = "external-secrets.io/v1alpha1"
            kind = "PushSecret"
            metadata = {
              name = parameters.bucket.bucketName
              namespace = parameters.secret.cc_namespace
            }
            spec = {
              updatePolicy = parameters.secret.eso_push_secret_update_policy
              deletionPolicy = parameters.secret.eso_push_secret_delete_policy
              refreshInterval = parameters.secret.eso_push_secret_refresh_interval
              secretStoreRefs = [
                {
                  name = parameters.secret.vault_secrestore_name
                  kind = parameters.secret.vault_secret_store_kind
                }
              ]
              selector = {
                secret = {
                  name = parameters.bucket.bucketName
                }
              }
              data = [
                {
                  match = {
                    secretKey = "AWS_ACCESS_KEY_ID"
                    remoteRef = {
                      remoteKey = parameters.secret.vault_secret_path
                      property = "AWS_ACCESS_KEY_ID"
                    }
                  }
                },
                {
                  match = {
                    secretKey = "AWS_SECRET_ACCESS_KEY"
                    remoteRef = {
                      remoteKey = parameters.secret.vault_secret_path
                      property = "AWS_SECRET_ACCESS_KEY"
                    }
                  }
                }
              ]
            }
          }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
          name = spec.providerConfigsRef.ccK8sProviderName
        }
      }
    }

_items += [_cephBucket,_sourceSecret,_destinationSecret,_pushSecret]

dxr = {
    **oxr
}

items = _items + [dxr]