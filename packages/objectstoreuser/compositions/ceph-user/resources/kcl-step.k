# KCL function for Ceph Bucket User composition
# Creates Rook CephObjectStoreUser and Kubernetes Secret resources

oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

# Rook CephObjectStoreUser
_cephUser = {
  apiVersion = "ceph.rook.io/v1"
  kind = "CephObjectStoreUser"
  metadata = {
    name = parameters?.userName
    namespace = parameters?.namespaceRook or "rook-ceph"
  }
  spec = {
    store = parameters?.storeName or "default"
    displayName = parameters?.displayName
    opMask = parameters?.operationMask or ["read", "write", "delete"]
  }
}
_items += [_cephUser]

# Kubernetes Secret for Ceph credentials
_cephSecret = {
  apiVersion = "v1"
  kind = "Secret"
  metadata = {
    name = "${parameters?.userName}-ceph-secret"
    namespace = parameters?.namespaceCeph
  }
  type = "Opaque"
  data = {}
}
_items += [_cephSecret]

# Return the composed resources
dxr = {
    **oxr
}

items = _items + [dxr]
