import json
# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters

# Extract frequently used OCDs values with null checks
_iamUserARN = ocds["iam-user"]?.Resource?.status?.atProvider?.arn or ""
_bucketARN = ocds["bucket"]?.Resource?.status?.atProvider?.arn or ""
_iamUserId = ocds["iam-user"]?.Resource?.status?.atProvider?.id or ""
_accessKeyId = ocds["iam-access-key"]?.Resource?.status?.atProvider?.id or ""
_accessKeySecret = ocds["iam-access-key"]?.Resource?.status?.atProvider?.secret or ""

# Initialize the items list
_items = []

# S3 Bucket
_bucket = {
    apiVersion = "s3.aws.upbound.io/v1beta1"
    kind = "Bucket"
    metadata = {
        name = parameters?.bucket?.bucketName
        annotations = {
            "krm.kcl.dev/composition-resource-name": "bucket"
        }
    }
    spec = {
        deletionPolicy = parameters?.bucket?.deletionPolicy
        forProvider = {
            region = parameters?.bucket?.bucketRegion
            forceDestroy = parameters?.bucket?.forceDestroy
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

# Bucket ACL
_bucketAcl = {
    apiVersion = "s3.aws.upbound.io/v1beta1"
    kind = "BucketACL"
    metadata = {
        name = "{}-acl".format(parameters?.bucket?.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "bucket-acl"
        }
    }
    spec = {
        forProvider = {
            region = parameters?.bucket?.bucketRegion
            bucket = parameters?.bucket?.bucketName
            acl = "private"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

# Bucket Ownership Controls
_bucketOwnershipControls = {
    apiVersion = "s3.aws.upbound.io/v1beta1"
    kind = "BucketOwnershipControls"
    metadata = {
        name = "{}-ownership".format(parameters?.bucket?.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "bucket-ownership"
        }
    }
    spec = {
        forProvider = {
            region = parameters?.bucket?.bucketRegion
            bucket = parameters?.bucket?.bucketName
            rule = [{
                objectOwnership = "BucketOwnerPreferred"
            }]
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

# Bucket Policy
# Define bucket policy as KCL object
_bucketPolicyObject = {
    Version = "2012-10-17"
    Statement = [
        {
            Sid = "ListObjectsInBucket"
            Principal = {
                AWS = _iamUserARN
            }
            Effect = "Allow"
            Action = ["s3:ListBucket"]
            Resource = [_bucketARN]
        },
        {
            Sid = "AllowGetObject"
            Principal = {
                AWS = _iamUserARN
            }
            Effect = "Allow"
            Action = "s3:GetObject"
            Resource = [_bucketARN, "{}/{}".format(_bucketARN, "*")]
        },
        {
            Sid = "AllowDeleteObject"
            Principal = {
                AWS = _iamUserARN
            }
            Effect = "Allow"
            Action = "s3:DeleteObject"
            Resource = [_bucketARN, "{}/{}".format(_bucketARN, "*")]
        },
        {
            Sid = "AllowPutObject"
            Principal = {
                AWS = _iamUserARN
            }
            Effect = "Allow"
            Action = "s3:PutObject"
            Resource = [_bucketARN, "{}/{}".format(_bucketARN, "*")]
        },
        {
            Sid = "AllowAbortMultipartUpload"
            Principal = {
                AWS = _iamUserARN
            }
            Effect = "Allow"
            Action = "s3:AbortMultipartUpload"
            Resource = [_bucketARN, "{}/{}".format(_bucketARN, "*")]
        },
        {
            Sid = "AllowListMultipartUploadParts"
            Principal = {
                AWS = _iamUserARN
            }
            Effect = "Allow"
            Action = "s3:ListMultipartUploadParts"
            Resource = [_bucketARN, "{}/{}".format(_bucketARN, "*")]
        },
        {
            Sid = "AllowListBucketMultipartUploads"
            Principal = {
                AWS = _iamUserARN
            }
            Effect = "Allow"
            Action = "s3:ListBucketMultipartUploads"
            Resource = [_bucketARN, "{}/{}".format(_bucketARN, "*")]
        },
        {
            Sid = "AllowPutObjectAcl"
            Principal = {
                AWS = _iamUserARN
            }
            Effect = "Allow"
            Action = "s3:PutObjectAcl"
            Resource = [_bucketARN, "{}/{}".format(_bucketARN, "*")]
        }
    ]
}

_bucketPolicy = {
    apiVersion = "s3.aws.upbound.io/v1beta1"
    kind = "BucketPolicy"
    metadata = {
        name = "{}-policy".format(parameters?.bucket?.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "bucket-policy"
        }
    }
    spec = {
        forProvider = {
            region = parameters?.bucket?.bucketRegion
            bucket = parameters?.bucket?.bucketName
            policy = json.encode(_bucketPolicyObject)
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

# IAM User
_iamUser = {
    apiVersion = "iam.aws.upbound.io/v1beta1"
    kind = "User"
    metadata = {
        name = "{}-user".format(parameters?.bucket?.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "iam-user"
        }
    }
    spec = {
        forProvider = {
            forceDestroy = parameters?.bucket?.forceDestroy
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

# IAM Access Key
_iamAccessKey = {
    apiVersion = "iam.aws.upbound.io/v1beta1"
    kind = "AccessKey"
    metadata = {
        name = "{}-access-key".format(parameters?.bucket?.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "iam-access-key"
        }
    }
    spec = {
        forProvider = {
            user = _iamUserId
        }
        writeConnectionSecretToRef = {
            name = parameters.secret.name
            namespace = parameters.secret.namespace
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
        }
    }
}

if parameters?.secret?.esoPushSecret:
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
              name = parameters?.bucketName
              namespace = parameters?.secret?.namespace
            }
            spec = {
              updatePolicy = parameters?.secret?.esoUpdatePolicy
              deletionPolicy = parameters?.secret?.esoDeletePolicy
              refreshInterval = parameters?.secret?.esoRefreshInterval
              secretStoreRefs = [
                {
                  name = parameters?.secret?.vaultSecretStore,
                  kind = parameters?.secret?.vaultSecretStoreKind
                }
              ]
              selector = {
                secret = {
                  name = parameters?.secret?.name
                }
              }
              data = [
                {
                  match = {
                    secretKey = "username"
                    remoteRef = {
                      remoteKey = parameters?.secret?.vaultSecretPath
                      property = "username"
                    }
                  }
                },
                {
                  match = {
                    secretKey = "password"
                    remoteRef = {
                      remoteKey = parameters?.secret?.vaultSecretPath
                      property = "password"
                    }
                  }
                }
              ]
            }
          }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
          name = spec.providerConfigsRef.k8sProviderName
        }
      }
    }

# Add all resources to items list
_items += [
    _bucket,
    _bucketAcl,
    _bucketOwnershipControls,
    _bucketPolicy,
    _iamUser,
    _iamAccessKey,
    _pushSecret
]

# Update the XR with status fields
dxr = {
    **oxr
    status = {
        iamUserARN = _iamUserARN
        bucketARN = _bucketARN
    }
}

items = _items + [dxr]
