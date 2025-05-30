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

    "{}-{:02d}-01T00:00:00Z".format(y, m)
}

_items = []
_groupIAC = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Group"
    metadata = {
        name = "{}-group-iac".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = p?.iacGroupName
        }
    }
    spec = {
        forProvider = {
            name = p?.iacGroupName
            path = p?.iacGroupName
            description = p?.iacGroupName
            requireTwoFactorAuthentication = True
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_statusExpireAt = status?.tokenExpireAt
_expireAt = None

if _statusExpireAt == None:
    _expireAt = calculateExpireAt()

_groupAccessToken = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "AccessToken"
    metadata = {
        name = "{}-token-iac".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "access-token"
        }
    }
    spec = {
        forProvider = {
            groupId = ocds[p?.iacGroupName]?.Resource?.status?.atProvider?.id
            name = "gitlab ci pat"
            accessLevel = 50
            expiresAt = _statusExpireAt if _statusExpireAt != None else _expireAt
            scopes = ["api"]
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
        writeConnectionSecretToRef = {
            name = "{}-ci-token".format(oxr.metadata.name)
            #todo why oxr.metadata.namespace doesnt work?
            namespace = "gitlab"
        }
    }
}

_pushSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-push-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "push-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "external-secrets.io/v1alpha1"
                kind = "PushSecret"
                metadata = {
                    name = "{}-iac-pat-push-secret".format(oxr.metadata.name)
                    #todo why oxr.metadata.namespace doesnt work?
                    namespace = "gitlab"
                }
                spec = {
                    updatePolicy = "Replace"
                    deletionPolicy = "Delete"
                    refreshInterval = "1m"
                    secretStoreRefs = [
                        {
                            name = "vault-secret-store"
                            kind = "ClusterSecretStore"
                        }
                    ]
                    selector = {
                        secret = {
                            name = "{}-ci-token".format(oxr.metadata.name)
                            namespace = oxr.metadata.namespace
                        }
                    }
                    data = [
                        {
                            match = {
                                remoteRef = {
                                    remoteKey = p?.ciTokenVaultPath
                                }
                            }
                        }
                    ]
                }
            }
        }
        readiness = {
            policy = "DeriveFromCelQuery"
            celQuery = '"status" in object && "conditions" in object.status && object.status.conditions.exists(c, c.type == "Ready" && c.status == "True" )'
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.kubernetesProvider
        }
    }
}

_projBootstrap = {
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XProject"
    metadata = {
        name = "{}-proj-bootstrap".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "bootstrap"
        }
    }
    spec = {
        parameters = {
            project = {
                name = "bootstrap"
                groupId = ocds[p?.iacGroupName]?.Resource?.status?.atProvider?.id
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
    metadata = {
        name = "{}-var-vault-path".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-auth-path"
        }
    }
    spec = {
        forProvider = {
            groupId = ocds[p?.iacGroupName]?.Resource?.status?.atProvider?.id
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
    metadata = {
        name = "{}-var-vault-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-auth-role"
        }
    }
    spec = {
        forProvider = {
            groupId = ocds[p?.iacGroupName]?.Resource?.status?.atProvider?.id
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
    metadata = {
        name = "{}-var-vault-fqdn".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-fqdn"
        }
    }
    spec = {
        forProvider = {
            groupId = ocds[p?.iacGroupName]?.Resource?.status?.atProvider?.id
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
    metadata = {
        name = "{}-var-private-repo-user".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "private-repo-user"
        }
    }
    spec = {
        forProvider = {
            groupId = ocds[p?.iacGroupName]?.Resource?.status?.atProvider?.id
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
    metadata = {
        name = "{}-var-private-repo".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "private-repo"
        }
    }
    spec = {
        forProvider = {
            groupId = ocds[p?.iacGroupName]?.Resource?.status?.atProvider?.id
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
    metadata = {
        name = "{}-var-private-repo-token-vault-path".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "private-repo-token-vault-path"
        }
    }
    spec = {
        forProvider = {
            groupId = ocds[p?.iacGroupName]?.Resource?.status?.atProvider?.id
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
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Group"
    metadata = {
        name = "{}-group-tenancy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = p?.tenancyGroupName
        }
    }
    spec = {
        forProvider = {
            name = p?.tenancyGroupName
            path = p?.tenancyGroupName
            description = p?.tenancyGroupName
            visibility = "internal"
            requireTwoFactorAuthentication = True
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_projDocs = {
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XProject"
    metadata = {
        name = "{}-proj-tenancy-docs".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "tenancy-docs"
        }
    }
    spec = {
        parameters = {
            project = {
                name = "tenancy-docs"
                groupId = ocds[p?.tenancyGroupName]?.Resource?.status?.atProvider?.id
                visibility = "internal"
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            gitlabProvider = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

_vaultJwtAuthBackend = {
    apiVersion = "jwt.vault.upbound.io/v1alpha1"
    kind = "AuthBackend"
    metadata = {
        name = "{}-vault-jwt-auth-backend-object".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-jwt-auth-backend-object"
        }
    }
    spec = {
        forProvider = {
            path = p?.gitlabRunnerJwtPath
            description = "JWT for Gitlab Runner"
            oidcDiscoveryUrl = "https://{}".format(p?.gitlabFqdn)
            boundIssuer = "https://{}".format(p?.gitlabFqdn)
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.vaultProvider
        }
    }
}

_vaultPolicy = {
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Policy"
    metadata = {
        name = "{}-vault-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-policy"
        }
    }
    spec = {
        forProvider = {
            name = "gitlab-ci-runner"
            policy = """path "secret/*" {
  capabilities = ["read", "list"]
}"""
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.vaultProvider
        }
    }
}

_vaultJwtAuthRole = {
    apiVersion = "jwt.vault.upbound.io/v1alpha1"
    kind = "AuthBackendRole"
    metadata = {
        name = "{}-vault-jwt-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-jwt-role"
        }
    }
    spec = {
        forProvider = {
            backend = p?.gitlabRunnerJwtPath
            roleName = p?.gitlabRunnerRoleName
            boundAudiences = ["https://{}".format(p?.vaultFqdn)]
            tokenPolicies = ["gitlab-ci-runner"]
            boundClaimsType = "glob"
            boundClaims = {
                ref_protected = "true"
            }
            userClaim = "user_email"
            roleType = "jwt"
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.vaultProvider
        }
    }
}

_items += [
    _groupIAC
    _groupAccessToken
    _pushSecret
    _projBootstrap
    _groupVarVaultAuthPath
    _groupVarVaultAuthRole
    _groupVarVaultFqdn
    _groupVarPrivateRepoUser
    _groupVarPrivateRepo
    _groupVarPrivateRepoTokenVaultPath
    _groupTenancy
    _projDocs
    _vaultJwtAuthBackend
    _vaultPolicy
    _vaultJwtAuthRole
]
dxr = {
    **oxr
}

finalDxr = {
    **dxr
    status.tokenExpireAt = _expireAt
} if _statusExpireAt == None else dxr

items = _items + [finalDxr]
