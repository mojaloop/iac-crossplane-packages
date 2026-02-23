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
                    namespace = projectName
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


_statusExpireAt = status?.tokenExpireAt
_expireAt = None

if _statusExpireAt == None:
    _expireAt = calculateExpireAt()

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
            expiresAt = _statusExpireAt if _statusExpireAt != None else _expireAt
            scopes = ["api", "read_api", "read_registry", "read_repository", "write_repository"]
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
        writeConnectionSecretToRef = {
            name = "{}-project-access-token".format(projectName)
            namespace = projectName
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

_envNamespaces = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-namespace".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "namespace-{}".format(projectName)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Namespace"
                metadata = {
                    name = projectName
                }
                annotations = {
                    "name" = projectName
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
                    namespace = projectName
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
                    namespace = projectName
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


_items += _envNamespaces + _environmentProjects + _projectIdSecrets + _projectAccessTokens + _projectTokenObserveSecrets + _groupVariables + _repoSecrets

dxr = {
    **oxr
}

finalDxr = {
    **dxr
    status.tokenExpireAt = _expireAt
} if _statusExpireAt == None else dxr

items = _items + [finalDxr]
