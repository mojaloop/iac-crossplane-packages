import json

# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
# Get Zitadel User Grants
_zitadel_user_grants = {
  apiVersion = "http.crossplane.io/v1alpha2"
  kind = "Request"
  metadata = {
    name = "{}-zug".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name" = "zitadel-user-grants"
    }
  }
  spec = {
    forProvider = {
      headers = {
          Authorization = ["Bearer {{ zitadel-provider-secret:zitadel-test:token }}"]
          "Content-Type" = ["application/json"]
      }
      mappings = [
        {
          action = "OBSERVE"
          url = ".payload.baseUrl"
          method = "POST"
          body = json.encode({
            "query": {
              "offset": "0"
              "limit": 100
              "asc": True
            }
            "queries": [
              {
                "projectNameQuery": {
                  "projectName": "${parameters.zitadelProjectName}"
                  "method": "3"
                }
              }
            ]
          })
        }
      ]
      payload = {
        baseUrl = parameters.zitadelUrl + "/management/v1/users/grants/_search"
      }
      waitTimeout = "5m"
      secretInjectionConfigs = [
        {
          secretRef = {
            name = parameters.zitadelAuth.patSecret.name
            namespace = parameters.zitadelAuth.patSecret.namespace
          }
          secretKey = parameters.zitadelAuth.patSecret.key
          responsePath = ".body.token"
        }
      ]
    }
    providerConfigRef = spec.providerConfigRef
    managementPolicies = spec.managementPolicies
  }
}
# Add the resources to the items list
_items += [_zitadel_user_grants]

dxr = {
    **oxr
}

items = _items + [dxr]
