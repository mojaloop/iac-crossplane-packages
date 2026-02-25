import datetime
import regex
import base64
import crypto

# Read the XR
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
status = oxr.status
parameters = spec.parameters


calculateExpireAt = lambda -> str {
    now = datetime.today()
    date = regex.split(now, " ")[0]

    _y = regex.split(date, "-")[0]
    _m = regex.split(date, "-")[1]
    _d = regex.split(date, "-")[2]

    y = int(_y) + 1
    m = int(_m) - 1 if int(_m) > 1 else 1

    "{}-{:02d}-01T00:00:00Z".format(y, m)
}

needsRenewal = lambda expiryDateStr: str -> bool {
    # Prepare current date components
    now = datetime.today()
    current_date_str = regex.split(now, " ")[0]
    now_y = int(regex.split(current_date_str, "-")[0])
    now_m = int(regex.split(current_date_str, "-")[1])
    now_d = int(regex.split(current_date_str, "-")[2])

    # Prepare expiry date components (if expiryDateStr exists)
    expiry_date_part = regex.split(expiryDateStr, "T")[0] if expiryDateStr else ""
    exp_y = int(regex.split(expiry_date_part, "-")[0]) if expiryDateStr else 0
    exp_m = int(regex.split(expiry_date_part, "-")[1]) if expiryDateStr else 0
    exp_d = int(regex.split(expiry_date_part, "-")[2]) if expiryDateStr else 0

    # Simplified Logic: Return True if any expiration condition is met
    # CHANGED: Explicitly check for empty string instead of (not expiryDateStr)
    (expiryDateStr == "") or \
    (exp_y < now_y) or \
    (exp_y == now_y and exp_m < now_m) or \
    (exp_y == now_y and exp_m == now_m and (exp_d - now_d) <= 7)
}


_items = []

_environments = (parameters?.environments or "").split(",")

_environmentProjects = [{
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XProject"
    metadata = {
        name = "project-{}".format(projectName)
        annotations = {
                "krm.kcl.dev/composition-resource-name" = "project-{}".format(projectName)
        }
    }
    spec = {
        parameters = {
            project = {
                name = projectName
                onlyAllowMergeIfPipelineSucceeds = False
                onlyAllowMergeIfAllDiscussionsAreResolved = False
                requestAccessEnabled = True
                pagesAccessLevel = "private"
                groupIdSelector = {
                  matchLabels = {
                    "gitlab.mojaloop.com/group-name" = parameters?.groupName
                  }
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            gitlabProvider = spec?.providerConfigsRef?.gitlabProvider
        }
    }
} for projectName in _environments or []
]

_projectIds = {
  projectName: ocds["project-{}".format(projectName)]?.Resource?.status?.atProvider?.id or ""
  for projectName in _environments or []
}


_projectIdSecrets = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "project-id-secret-{}".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "project-id-secret-{}".format(projectName)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "project-id-secret-{}".format(projectName)
                    namespace = "gitlab"
                }
                # Using stringData to handle the ID (which might be int or string) safely
                data = {
                    "project_id" = base64.encode(str(_projectIds[projectName]))
                    "gitlab_fqdn" = base64.encode(str(parameters?.gitlabFqdn))
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.kubernetesProvider
        }
    }
} for projectName in _environments or []
]


_existingExpirations = status?.tokenExpirations or {}

_projectExpirations = {
    projectName: calculateExpireAt() if needsRenewal(_existingExpirations[projectName]) else _existingExpirations[projectName]
    for projectName in _environments or []
}

_projectAccessTokens = [{
    apiVersion = "projects.gitlab.crossplane.io/v1alpha1"
    kind = "AccessToken"
    metadata = {
        name = "accesstoken-{}".format(projectName)
        annotations = {
                "krm.kcl.dev/composition-resource-name" = "accesstoken-{}".format(projectName)
        }

    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            projectIdSelector = {
                matchLabels = {
                   "gitlab.mojaloop.com/project-name" = projectName
                }
            }
            name = "accesstoken-{}".format(projectName)
            accessLevel = 40
            expiresAt = _projectExpirations[projectName]
            scopes = ["api", "read_api", "read_registry", "read_repository", "write_repository"]
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
        writeConnectionSecretToRef = {
            name = "{}-project-access-token".format(projectName)
            namespace = "gitlab"
        }
    }

} for projectName in _environments or []
]

# Helper function to transform HELM_CLASSIC_PROXY_REPOS
_transformClassicRepos = lambda val, baseUrl: str {
    items = (val or "").split(",")
    result = [
        "{}={}/{}".format(item.split("=")[1], baseUrl, item.split("=")[0])
        for item in items if item and "=" in item
    ]
    ",".join(result)
}

# Helper function to transform HELM_OCI_PROXY_REPOS
_transformOciRepos = lambda val, baseUrl: str {
    items = (val or "").split(",")
    result = [
        "{}={}".format(item.split("=")[1], baseUrl)
        for item in items if item and "=" in item
    ]
    ",".join(result)
}

_groupVariables = [ {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata = {
        name = "var-{}".format(variable.key.replace("_", "-").lower())
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "var-{}".format(variable.key.replace("_", "-").lower())
        }
    }
    spec = {
        forProvider = {
            groupIdSelector = {
                matchLabels = {
                "gitlab.mojaloop.com/group-name" = parameters?.groupName
                }
            }
            key = variable.key

            value = _transformClassicRepos(variable.value, parameters?.classicHelmRepoBaseUrl) if variable.key == "HELM_CLASSIC_PROXY_REPOS" else (_transformOciRepos(variable.value, parameters?.ociHelmRepoBaseUrl) if variable.key == "HELM_OCI_PROXY_REPOS" else variable.value)

            protected = variable.protected
            masked = variable.masked
            environmentScope = variable.environmentScope
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
} for variable in parameters?.groupVariables or []
]


_projectTokenObserveSecrets = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "project-token-observe-{}".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "project-token-observe-{}".format(projectName)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-project-access-token".format(projectName)
                    namespace = "gitlab"
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec?.providerConfigsRef?.kubernetesProvider
        }
    }
} for projectName in _environments or []]

_projectTokens = {
    projectName: ocds["project-token-observe-{}".format(projectName)]?.Resource?.status?.atProvider?.manifest?.data?.token or ""
    for projectName in _environments or []
}

_repoSecrets = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-repo-secret".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "repo-secret-{}".format(projectName)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-repo-secret".format(projectName)
                    namespace = parameters?.argocdNamespace
                }
                labels = {
                    "argocd.argoproj.io/secret-type" = "repo-creds"
                }
                data = {
                    "password"  = _projectTokens[projectName]
                    "url"       = base64.encode(ocds["project-{}".format(projectName)]?.Resource?.status?.atProvider?.httpUrlToRepo)
                    "type"      = base64.encode("git")
                    "project"   = base64.encode("default")
                    "username"  = base64.encode("token")
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.kubernetesProvider
        }
    }
} for projectName in _environments or []
]

_VaultEnvTokenObserveSecret = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "vault-env-token-observe-{}".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "vault-env-token-observe-{}".format(projectName)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "env-token-secret-{}".format(projectName)
                    namespace = "gitlab"
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}for projectName in _environments or []
]

_envVaulttokens = {
  projectName: base64.decode(ocds["vault-env-token-observe-{}".format(projectName)]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_token"]) or ""
  for projectName in _environments or []
}


_items += _environmentProjects + _projectIdSecrets + _projectAccessTokens + _projectTokenObserveSecrets + _groupVariables + _repoSecrets

dxr = {
    **oxr
}

items = _items + [{
    **oxr
    status.tokenExpirations = _projectExpirations
}]
