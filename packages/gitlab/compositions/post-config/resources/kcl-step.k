import datetime
import regex

# Read the XR
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
status = oxr.status
p = spec.parameters

calculateExpireAt = lambda -> str {
  now = datetime.today()
  date = regex.split(now, " ")[0]

  _y = regex.split(date, "-")[0]
  _m = regex.split(date, "-")[1]
  _d = regex.split(date, "-")[2]

  y = int(_y) + 1
  m = int(_m) - 1 if int(_m) > 1 else 1

  "{}-{}-01T00.00.00Z".format(y,"{:02d}".format(m))
}


#render members
_items = []
_groupIAC = {
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XGroup"
    metadata.annotations: {"krm.kcl.dev/composition-resource-name" = "iac"}
    spec = {
        parameters = {
            group = {
                name = "xiac"
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            gitlabProvider = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_dxrExpire = None
_statusExpireAt = status?.tokenExpireAt
if _statusExpireAt == None:
  _statusExpireAt = calculateExpireAt

  _dxrExpire = {
    **oxr
    status.tokenExpireAt = _statusExpireAt
  }

_groupAccessToken = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind: "AccessToken"
    metadata.annotations: {"krm.kcl.dev/composition-resource-name" = "access-token"}
    spec = {
        forProvider = {
            groupId = ocds["iac"]?.Resource?.status?.groupId
            name = "gitlab ci pat"
            accessLevel = 50
            expiresAt = _statusExpireAt
            scopes = ["api"]
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_projBootstrap = {
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XProject"
    metadata.annotations: {"krm.kcl.dev/composition-resource-name" = "bootstrap"}
    spec = {
        parameters = {
            project = {
                name = "bootstrap"
                groupId = ocds["iac"]?.Resource?.status?.groupId
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            gitlabProvider = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_groupVarVaultAuthPath = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata.annotations = {
        "krm.kcl.dev/composition-resource-name" = "vault-auth-path"
    }
    spec = {
        forProvider = {
            groupId = ocds["iac"]?.Resource?.status?.groupId
            key = "VAULT_AUTH_PATH"
            value = p?.gitlabRunnerJwtPath
            protected = True
            masked = False
            environmentScope = "*"
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_groupVarVaultAuthRole = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata.annotations = {
        "krm.kcl.dev/composition-resource-name" = "vault-auth-role"
    }
    spec = {
        forProvider = {
            groupId = ocds["iac"]?.Resource?.status?.groupId
            key = "VAULT_AUTH_ROLE"
            value = p?.gitlabRunnerRoleName
            protected = True
            masked = False
            environmentScope = "*"
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_groupVarVaultFqdn = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata.annotations = {
        "krm.kcl.dev/composition-resource-name" = "vault-fqdn"
    }
    spec = {
        forProvider = {
            groupId = ocds["iac"]?.Resource?.status?.groupId
            key = "VAULT_FQDN"
            value = p?.vaultFqdn
            protected = True
            masked = False
            environmentScope = "*"
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_groupVarPrivateRepoUser = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata.annotations = {
        "krm.kcl.dev/composition-resource-name" = "private-repo-user"
    }
    spec = {
        forProvider = {
            groupId = ocds["iac"]?.Resource?.status?.groupId
            key = "PRIVATE_REPO_USER"
            value = p?.privateRepoUser
            protected = True
            masked = False
            environmentScope = "*"
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_groupVarPrivateRepo = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata.annotations = {
        "krm.kcl.dev/composition-resource-name" = "private-repo"
    }
    spec = {
        forProvider = {
            groupId = ocds["iac"]?.Resource?.status?.groupId
            key = "PRIVATE_REPO"
            value = p?.privateRepo
            protected = True
            masked = False
            environmentScope = "*"
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_groupVarPrivateRepoTokenVaultPath = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata.annotations = {
        "krm.kcl.dev/composition-resource-name" = "private-repo-token-vault-path"
    }
    spec = {
        forProvider = {
            groupId = ocds["iac"]?.Resource?.status?.groupId
            key = "PRIVATE_REPO_TOKEN_PATH"
            value = p?.privateRepo
            protected = True
            masked = False
            environmentScope = "*"
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_groupTenancy = {
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XGroup"
    metadata.annotations: {"krm.kcl.dev/composition-resource-name" = "tenancy-internal"}
    spec = {
        parameters = {
            group = {
                name = "xtenancy-internal"
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            gitlabProvider = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_projDocs = {
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XProject"
    metadata.annotations: {"krm.kcl.dev/composition-resource-name" = "tenancy-docs"}
    spec = {
        parameters = {
            project = {
                name = "tenancy-docs"
                groupId = ocds["tenancy-internal"]?.Resource?.status?.groupId
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            gitlabProvider = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_items += [
    _groupIAC
    _groupAccessToken
    _projBootstrap
    _groupVarVaultAuthPath
    _groupVarVaultAuthRole
    _groupVarVaultFqdn
    _groupVarPrivateRepoUser
    _groupVarPrivateRepo
    _groupVarPrivateRepoTokenVaultPath
    _groupTenancy
    _projDocs
]
dxr = {**oxr}
dxrs = [dxr, _dxrExpire] if _dxrExpire != None else [dxr]
items = _items + [dxrs]
