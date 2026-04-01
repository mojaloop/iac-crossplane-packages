# KCL function for IAM User composition
# Creates AWS IAM User, AccessKey, and Kubernetes Secret resources

oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

# AWS IAM User
_iamUser = {
  apiVersion = "iam.aws.upbound.io/v1beta1"
  kind = "User"
  metadata = {
    name = parameters?.userName
  }
  spec = {
    forProvider = {}
    providerConfigRef = {
      name = parameters?.awsProviderName
    }
  }
}
_items += [_iamUser]

# AWS Access Key
_accessKey = {
  apiVersion = "iam.aws.upbound.io/v1beta1"
  kind = "AccessKey"
  metadata = {
    name = "${parameters?.userName}-key"
  }
  spec = {
    forProvider = {
      userRef = {
        name = parameters?.userName
      }
    }
    providerConfigRef = {
      name = parameters?.awsProviderName
    }
  }
}
_items += [_accessKey]

# Kubernetes Secret for IAM credentials
_iamSecret = {
  apiVersion = "v1"
  kind = "Secret"
  metadata = {
    name = "${parameters?.userName}-iam-secret"
    namespace = parameters?.namespace
  }
  type = "Opaque"
  data = {
    accesskeyid = ""
    secretaccesskey = ""
  }
}
_items += [_iamSecret]

# Return the composed resources
dxr = {
    **oxr
}

items = _items + [dxr]
