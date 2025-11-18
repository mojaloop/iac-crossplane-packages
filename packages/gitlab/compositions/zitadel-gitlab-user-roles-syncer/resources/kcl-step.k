import json
import base64

# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters

# Initialize the items list
_items = []

# Get the project name for resource naming (use zitadelProjectName)
projectName = parameters?.zitadelProjectName or "default"

# ============================================
# 1. OBSERVE GITLAB OIDC SECRET
# ============================================
_k8sObserveGitlabOidcSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "gitlab-oidc-secret-observe-{}".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "gitlab-oidc-secret-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters?.gitlabOidcSecret?.name or "gitlab-oidc-secret"
                    namespace = parameters?.gitlabOidcSecret?.namespace or "gitlab"
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}

# ============================================
# OBSERVE ZITADEL PROJECT ID CONFIGMAP
# ============================================
_k8sObserveZitadelProjectConfigMap = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "zitadel-project-config-observe-{}".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-project-config-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = parameters.zitadelProjectConfigMap.name
                    namespace = parameters.zitadelProjectConfigMap.namespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}

# Extract project ID from ConfigMap
_projectIdFromConfigMap = ocds["zitadel-project-config-observe"]?.Resource?.status?.atProvider?.manifest?.data?["projectId"] or ""

# ============================================
# 3. EXTRACT CLIENT CREDENTIALS FROM OBSERVED SECRET
# ============================================
_observedSecretData = ocds.get("gitlab-oidc-secret-observe", {})?.Resource?.status?.atProvider?.manifest?.data
_providerDataEncoded = _observedSecretData?.get("provider", "") if _observedSecretData else ""
_providerDataJson = base64.decode(_providerDataEncoded) if _providerDataEncoded else "{}"

# Safe JSON decode with proper fallback handling
_providerData = {}
if _providerDataJson and _providerDataJson != "{}" and _providerDataJson != "":
    _decoded = json.decode(_providerDataJson)
    _providerData = _decoded if _decoded else {}

# Safe access to nested properties with null checks
_args = _providerData.get("args", {}) if _providerData else {}
_clientOptions = _args.get("client_options", {}) if _args else {}

_clientId = _clientOptions.get("identifier", "") if _clientOptions else ""
_clientSecret = _clientOptions.get("secret", "") if _clientOptions else ""
_zitadelHost = _clientOptions.get("host", "") if _clientOptions else ""
_zitadelUrl = "https://{}".format(_zitadelHost) if _zitadelHost else parameters?.zitadelUrl or ""
_zitadelProjectId = _projectIdFromConfigMap or ""
_gitlabUrl = parameters?.gitlabUrl or ""

# ============================================
# 4. GET BEARER TOKEN FROM ZITADEL
# ============================================
_zitadelTokenRequest = {
    apiVersion = "http.crossplane.io/v1alpha2"
    kind = "Request"
    metadata = {
        name = "{}-zitadel-token".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-token-request"
        }
    }
    spec = {
        forProvider = {
            headers = {
                "Content-Type" = ["application/x-www-form-urlencoded"]
            }
            mappings = [
                {
                    action = "OBSERVE"
                    url = "{}/oauth/v2/token".format(_zitadelUrl)
                    method = "POST"
                    body = "client_id={}&client_secret={}&grant_type=client_credentials&scope=openid%20email%20profile%20urn:iam:org:project:roles%20urn:zitadel:iam:org:projects:roles%20urn:zitadel:iam:org:project:id:{}:aud".format(
                        _clientId,
                        _clientSecret,
                        _zitadelProjectId
                    )
                }
            ]
            waitTimeout = "5m"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProvider
        }
        managementPolicies = spec.managementPolicies
    }
} if _clientId and _clientSecret else None

# Extract bearer token from response
_tokenResponse = ocds.get("zitadel-token-request", {})?.Resource?.status?.atProvider
_bearerToken = _tokenResponse?.response?.body?.access_token if _tokenResponse else ""

# ============================================
# 5. GET ZITADEL USER GRANTS
# ============================================
_zitadelUserGrantsRequest = {
    apiVersion = "http.crossplane.io/v1alpha2"
    kind = "Request"
    metadata = {
        name = "{}-zitadel-user-grants".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-user-grants"
        }
    }
    spec = {
        forProvider = {
            headers = {
                Authorization = ["Bearer {}".format(_bearerToken)]
                "Content-Type" = ["application/json"]
            }
            mappings = [
                {
                    action = "OBSERVE"
                    url = "{}/management/v1/users/grants/_search".format(_zitadelUrl)
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
                                    "projectName": parameters?.zitadelProjectName or "default"
                                    "method": "3"
                                }
                            }
                        ]
                    })
                }
            ]
            waitTimeout = "5m"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProvider
        }
        managementPolicies = spec.managementPolicies
    }
} if _bearerToken else None

# Extract user grants from response
_zitadelUserGrants = ocds["zitadel-user-grants"]?.Resource?.status?.atProvider?.response?.body?.result or ""


# ============================================
# 6. OBSERVE GITLAB ROOT TOKEN SECRET
# ============================================
_k8sObserveGitlabRootTokenSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "gitlab-roottoken-secret-observe-{}".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "gitlab-roottoken-secret-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters?.gitlabRootTokenSecret?.name or "root-token-secret"
                    namespace = parameters?.gitlabRootTokenSecret?.namespace or "gitlab"
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}

_observedRootTokenData = ocds.get("gitlab-roottoken-secret-observe", {})?.Resource?.status?.atProvider?.manifest?.data
_gitlabTokenEncoded = _observedRootTokenData?.get("token", "") if _observedRootTokenData else ""
_gitlabToken = base64.decode(_gitlabTokenEncoded) if _gitlabTokenEncoded else ""

# ============================================
# 7. GET ALL GITLAB USERS
# ============================================
_gitlabUsersRequest = {
    apiVersion = "http.crossplane.io/v1alpha2"
    kind = "Request"
    metadata = {
        name = "{}-gitlab-users".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "gitlab-users"
        }
    }
    spec = {
        forProvider = {
            headers = {
                "PRIVATE-TOKEN" = [_gitlabToken]
                "Content-Type" = ["application/json"]
            }
            mappings = [
                {
                    action = "OBSERVE"
                    url = "{}/api/v4/users?per_page=100&active=true".format(_gitlabUrl)
                    method = "GET"
                }
            ]
            waitTimeout = "5m"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProvider
        }
        managementPolicies = spec.managementPolicies
    }
} if _gitlabToken else None

# Extract GitLab users from response
_gitlabUsers = ocds["gitlab-users"]?.Resource?.status?.atProvider?.response?.body or ""

# ============================================
# 8. GET GITLAB GROUP DETAILS
# ============================================
_gitlabGroupPath = parameters?.gitlabGroupPath or ""

_gitlabGroupRequest = {
    apiVersion = "http.crossplane.io/v1alpha2"
    kind = "Request"
    metadata = {
        name = "{}-gitlab-group".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "gitlab-group"
        }
    }
    spec = {
        forProvider = {
            headers = {
                "PRIVATE-TOKEN" = [_gitlabToken]
                "Content-Type" = ["application/json"]
            }
            mappings = [
                {
                    action = "OBSERVE"
                    url = "{}/api/v4/groups/{}".format(_gitlabUrl, _gitlabGroupPath.replace("/", "%2F"))
                    method = "GET"
                }
            ]
            waitTimeout = "5m"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProvider
        }
        managementPolicies = spec.managementPolicies
    }
} if _gitlabToken else None




# Add the resources to the items list
_items += [
    _k8sObserveGitlabOidcSecret,
    _k8sObserveZitadelProjectConfigMap,
    _k8sObserveGitlabRootTokenSecret
]

_conditionalItems = []
if _zitadelTokenRequest:
    _conditionalItems += [_zitadelTokenRequest]
if _zitadelUserGrantsRequest:
    _conditionalItems += [_zitadelUserGrantsRequest]
if _gitlabGroupRequest:
    _conditionalItems += [_gitlabGroupRequest]
if _gitlabUsersRequest:
    _conditionalItems += [_gitlabUsersRequest]

_items += _conditionalItems
dxr = {
    **oxr
}

items = _items + [dxr]
