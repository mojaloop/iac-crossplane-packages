import datetime
import regex
import base64

# Read the XR
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters


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
        forProvider = {
            projectIdSelector = {
                matchLabels = {
                   "gitlab.mojaloop.com/project-name" = projectName
                }
            }
            name = "accesstoken-{}".format(projectName)
            accessLevel = 40
            scopes = ["api", "read_api", "read_registry", "read_repository", "write_repository"]
            expiresAt = parameters?.expiresAt
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
        writeConnectionSecretToRef = {
            name = "{}-repo-secret".format(projectName)
            namespace = parameters?.namespace
        }
    }

} for projectName in _environments or []
]

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
            value = variable.value
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

_observe_repo_secret = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-repo-secret-observe".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "repo-secret-observe-{}".format(projectName)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-repo-secret".format(projectName)
                    namespace = parameters?.namespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec?.providerConfigsRef?.kubernetesProvider
        }
    }
} for projectName in _environments or []
]

_repo_tokens = {
  projectName: base64.decode(ocds["repo-secret-observe-{}".format(projectName)]?.Resource?.status?.atProvider?.manifest?.data?["token"]) or ""
  for projectName in _environments or []
}

_repoSecrets = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-repo-creds".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "repo-creds-{}".format(projectName)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-repo-creds".format(projectName)
                    namespace = parameters?.argocdNamespace
                }
                labels = {
                    "argocd.argoproj.io/secret-type" = "repo-creds"
                }
                data = {
                    "password"  = ocds["repo-secret-observe-{}".format(projectName)]?.Resource?.status?.atProvider?.manifest?.data?["token"]
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

_k8sObserveSecret = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "gitlab-env-token-k8secret-observe-{}".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "gitlab-env-token-k8secret-observe-{}".format(projectName)
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
  projectName: ocds["gitlab-env-token-k8secret-observe-{}".format(projectName)]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_token"] or ""
  for projectName in _environments or []
}

_vaultTokenUpdateRequests = [{
    apiVersion = "http.crossplane.io/v1alpha2"
    kind = "Request"
    metadata = {
        name = "{}-vault-token-update-request".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "{}-vault-token-update-request".format(projectName)
        }
    }
    spec = {
        deletionPolicy = "Orphan"
        forProvider = {
            payload = {
               baseUrl = "https://{}/api/v4/projects/{}/repository/files/%2Evault_token_trigger?ref=main".format(parameters?.gitlabFqdn, _projectIds[projectName])
               body = """
                    {{
                        "branch": "main",
                        "commit_message": "tf_trigger: vault_token_update",
                        "content": "{}",
                        "encoding": "text",
                        "author_name": "Crossplane"
                    }}
                    """.format(_envVaulttokens[projectName])
            }
            headers = {
                "PRIVATE-TOKEN" = [_repo_tokens[projectName]]
                "Content-Type" =  ["application/json"]
            }
            mappings = [
                {
                    action = "OBSERVE"
                    method = "GET"
                    url = ".payload.baseUrl"
                },
                {
                    action = "CREATE"
                    method = "POST"
                    body = ".payload.body"
                    url = ".payload.baseUrl"
                },
                {
                    action = "UPDATE"
                    method = "PUT"
                    url = ".payload.baseUrl"
                    body = ".payload.body"
                }
            ]
            expectedResponseCheck = {
                type = "CUSTOM"
                logic = """
            if (.response.statusCode == 200)
            and (.response.body.content == .payload.body.content)
            then true else false end
            """
            }

            isRemovedCheck = {
                type = "CUSTOM"
                logic = """
            if .response.statusCode == 404 then true else false end
            """
            }
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.httpProvider
        }
    }
} for projectName in _environments or []
]

_items += _environmentProjects + _projectAccessTokens + _groupVariables + _observe_repo_secret + _repoSecrets + _k8sObserveSecret

dxr = {
    **oxr
}

items = _items + [dxr]
