import datetime
import regex

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
            name = "Argocd project access token"
            accessLevel = 20
            scopes = ["read_api", "read_registry"]
            expiresAt = parameters?.expiresAt
        }
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
        name = "var-{}".format(variable.key)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "var-{}".format(variable.key)
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
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
} for variable in parameters?.groupVariables or []
]



_items += _environmentProjects + _projectAccessTokens + _groupVariables

dxr = {
    **oxr
}

items = _items + [dxr]
