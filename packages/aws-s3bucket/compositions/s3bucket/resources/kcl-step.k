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
        name = parameters.bucketName
        annotations = {
            "krm.kcl.dev/composition-resource-name": "bucket"
        }
    }
    spec = {
        deletionPolicy = parameters.deletionPolicy
        forProvider = {
            region = parameters.bucketRegion
            forceDestroy = parameters.forceDestroy
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
        name = "{}-acl".format(parameters.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "bucket-acl"
        }
    }
    spec = {
        forProvider = {
            region = parameters.bucketRegion
            bucket = parameters.bucketName
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
        name = "{}-ownership".format(parameters.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "bucket-ownership"
        }
    }
    spec = {
        forProvider = {
            region = parameters.bucketRegion
            bucket = parameters.bucketName
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
        name = "{}-policy".format(parameters.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "bucket-policy"
        }
    }
    spec = {
        forProvider = {
            region = parameters.bucketRegion
            bucket = parameters.bucketName
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
        name = "{}-user".format(parameters.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "iam-user"
        }
    }
    spec = {
        forProvider = {
            forceDestroy = parameters.forceDestroy
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
        name = "{}-access-key".format(parameters.bucketName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "iam-access-key"
        }
    }
    spec = {
        forProvider = {
            user = _iamUserId
        }
        writeConnectionSecretToRef = {
            name = parameters.bucketName
            namespace = oxr.metadata.namespace if oxr.metadata.namespace else "crossplane-system"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.awsProviderName
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
    _iamAccessKey
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
