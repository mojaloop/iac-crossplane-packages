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
_zitadelProjectId = ocds["zitadel-project-config-observe"]?.Resource?.status?.atProvider?.manifest?.data?["projectId"] or ""

# Extract OIDC Secret ID and key
_oidcSecretJson = json.decode(base64.decode(ocds["gitlab-oidc-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?["provider"])) if ocds["gitlab-oidc-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?["provider"] else {}
_args = _oidcSecretJson["args"] if _oidcSecretJson and "args" in _oidcSecretJson else {}
_clientOptions = _args["client_options"] if _args and "client_options" in _args else {}
_clientId = _clientOptions["identifier"] if _clientOptions and "identifier" in _clientOptions else ""
_clientSecret = _clientOptions["secret"] if _clientOptions and "secret" in _clientOptions else ""

_part1 = "client_id=" + _clientId
_part2 = "client_secret=" + _clientSecret
_part3 = "grant_type=client_credentials"
_part4 = "scope=openid%20email%20profile%20urn:iam:org:project:roles%20urn:zitadel:iam:org:projects:roles%20urn:zitadel:iam:org:project:id:" + _zitadelProjectId + ":aud"

_body = _part1 + "&" + _part2 + "&" + _part3 + "&" + _part4

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
            payload = {
                baseUrl = "{}/oauth/v2/token".format(parameters?.zitadelUrl)
            }
            mappings = [
                {
                    action = "OBSERVE"
                    url = ".payload.baseUrl"
                    method = "POST"
                    body = "client_id=" + _clientId + "&client_secret=" + _clientSecret + "&grant_type=client_credentials&scope=openid%20email%20profile%20urn:iam:org:project:roles%20urn:zitadel:iam:org:projects:roles%20urn:zitadel:iam:org:project:id:" + _zitadelProjectId + ":aud"
                }
            ]
            waitTimeout = "5m"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProvider
        }
        managementPolicies = spec.managementPolicies
    }
}


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

_gitlabToken = base64.decode(ocds["gitlab-roottoken-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?["token"]) or ""

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
            payload = {
                baseUrl = "{}/api/v4/users?per_page=100&active=true".format(parameters?.gitlabUrl)
            }
            mappings = [
                {
                    action = "OBSERVE"
                    url = ".payload.baseUrl"
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
}


# Add the resources to the items list
_items = [
    _k8sObserveGitlabOidcSecret,
    _k8sObserveZitadelProjectConfigMap,
    _k8sObserveGitlabRootTokenSecret,
    _gitlabUsersRequest,
    _zitadelTokenRequest
]

dxr = {
    **oxr
}

items = _items + [dxr]
