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
_zitadelOrgId = ocds["zitadel-project-config-observe"]?.Resource?.status?.atProvider?.manifest?.data?["orgId"] or ""

# Extract OIDC client ID and secret
_clientId = base64.decode(ocds["gitlab-oidc-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"]) if ocds["gitlab-oidc-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"] else ""
_clientSecret = base64.decode(ocds["gitlab-oidc-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_secret"]) if ocds["gitlab-oidc-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_secret"] else ""

_part1 = "client_id=" + _clientId
_part2 = "client_secret=" + _clientSecret
_part3 = "grant_type=client_credentials"
_part4 = "scope=openid%20email%20profile%20urn:iam:org:project:roles%20urn:zitadel:iam:org:projects:roles%20urn:zitadel:iam:org:project:id:" + _zitadelProjectId + ":aud" + "%20urn:zitadel:iam:org:id:" + _zitadelOrgId + "%20urn:zitadel:iam:org:project:id:zitadel:aud"

_body_content = _part1 + "&" + _part2 + "&" + _part3 + "&" + _part4

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
        deletionPolicy = "Orphan"
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
                    body = """\n"{}"\n""".format(_body_content)
                }
            ]
            waitTimeout = "5m"
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProvider
        }
        managementPolicies = ["*"]
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
        deletionPolicy = "Orphan"
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
        managementPolicies = ["*"]
    }
}

_zitadelAccessToken = json.decode(ocds["zitadel-token-request"]?.Resource?.status?.response?.body or "{}")?.access_token or ""

_zitadelGrantsRequest = {
    apiVersion = "http.crossplane.io/v1alpha2"
    kind = "Request"
    metadata = {
        name = "{}-zitadel-grants".format(oxr.metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name" = "zitadel-grants-request"}
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            headers = {
                "Authorization" = ["Bearer {}".format(_zitadelAccessToken)]
                "Content-Type" = ["application/json"]
            }
            payload = {
                baseUrl = "{}/management/v1/users/grants/_search".format(parameters?.zitadelUrl)
            }
            mappings = [{
                action = "OBSERVE"
                url = ".payload.baseUrl"
                method = "POST"
                # Search for grants within this specific project
                body = json.encode({"queries": [{"projectIdQuery": {"projectId": _zitadelProjectId}}]})
            }]
        }
        providerConfigRef.name = spec.providerConfigsRef.httpProvider
        managementPolicies = ["*"]
    }
}

# Decode the observed response bodies
_gitlabUsersBody = ocds["gitlab-users"]?.Resource?.status?.response?.body or "[]"
_zitadelGrantsBody = ocds["zitadel-grants-request"]?.Resource?.status?.response?.body or "{}"

_gitlabUsers = json.decode(_gitlabUsersBody)
_zitadelGrantsResponse = json.decode(_zitadelGrantsBody)
_userGrantData = _zitadelGrantsResponse?.result or []

# Map GitLab emails to their User IDs (e.g., "janedoe@infitx.com" -> 7)
_emailToGitlabId = {u.email: u.id for u in _gitlabUsers if u?.email}

# Define Priority Mapping
# If a user has "gitlab_administrators", they get "owner".
# Add other roles here in order of increasing power.
_rolePriority = [
    {"zitadel": parameters.developerRbacGroup, "gitlab": "developer"},
    {"zitadel": parameters.maintainerRbacGroup, "gitlab": "maintainer"},
    {"zitadel": parameters.adminRbacGroup, "gitlab": "owner"}
]

# Process memberships
_finalMemberships = {
    _grant.email: {
        "gitlab_user_id": _emailToGitlabId[_grant.email],
        # Determine the highest level by checking roles against the priority list
        "access_level": [
            _p.gitlab for _p in _rolePriority if _p.zitadel in (_grant.roleKeys or [])
        ][-1] # Select the last match (highest priority)
    }
    for _grant in _userGrantData
    # Filter: Only if the grant has an email and that email exists in GitLab
    if _grant?.email and _grant.email in _emailToGitlabId and [
        _p.gitlab for _p in _rolePriority if _p.zitadel in (_grant.roleKeys or [])
    ]
}

_debugData = {
    _email: {
        gitlab_user_id = str(_data.gitlab_user_id)
        access_level = _data.access_level
    } for _email, _data in _finalMemberships
}

_debugConfigMap = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-membership-debug".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "membership-debug-log"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = "{}-membership-debug".format(projectName)
                    namespace = parameters.zitadelProjectConfigMap.namespace
                }
                data = {
                    "calculated_memberships": json.encode(_debugData)
                    "raw_zitadel_grant_count": str(len(_userGrantData))
                    "matched_user_count": str(len(_finalMemberships))
                }
            }
        }
        # Using default management policies so Crossplane creates/updates it
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}

_groupMembershipResources = [
    {
        apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
        kind = "Member"
        metadata = {
            # Sanitize email for K8s name: david@infitx.com -> david-infitx-com
            name = "{}-member-{}".format(projectName, _email.replace("@", "-").replace(".", "-"))
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "gitlab-member-{}".format(_email)
            }
        }
        spec = {
            forProvider = {
                groupId = parameters.gitlabGroupPath
                userId = _data.gitlab_user_id
                accessLevel = _data.access_level
            }

            providerConfigRef = {
                name = spec.providerConfigsRef.gitlabProvider
            }
            managementPolicies = spec.managementPolicies
        }
    } for _email, _data in _finalMemberships
]

# Add the resources to the items list
_items = [
    _k8sObserveGitlabOidcSecret,
    _k8sObserveZitadelProjectConfigMap,
    _k8sObserveGitlabRootTokenSecret,
    _gitlabUsersRequest,
    _zitadelTokenRequest,
    _zitadelGrantsRequest,
    _debugConfigMap
] + _groupMembershipResources

dxr = {
    **oxr
}

items = _items + [dxr]
