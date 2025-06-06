import base64

# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

# Get the default organization ID
# Observe Zitadel admin sa secret
_observe_org_id_secret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-org-id-secret-observe".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-org-id-secret-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.organizationIdSecretRef?.name
                    namespace = parameters.organizationIdSecretRef?.namespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_orgId = base64.decode(ocds["zitadel-org-id-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?[parameters.organizationIdSecretRef?.key]) or ""

# Create Zitadel Project
_project = {
    apiVersion = "zitadel.zitadel.crossplane.io/v1alpha1"
    kind = "Project"
    metadata = {
        name = "{}-project".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-project"
        }
    }
    spec = {
        forProvider = {
            name = "vault"
            projectRoleAssertion = True
            projectRoleCheck = True
            hasProjectCheck = True
            orgId = _orgId
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

# Create OIDC Application
_oidcApp = {
    apiVersion = "application.zitadel.crossplane.io/v1alpha1"
    kind = "Oidc"
    metadata = {
        name = "{}-oidc-app".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-oidc-app"
        }
    }
    spec = {
        forProvider = {
            name = "vault"
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            redirectUris = ["https://{}/ui/vault/auth/oidc/oidc/callback".format(parameters.vaultFqdn)]
            responseTypes = ["OIDC_RESPONSE_TYPE_CODE"]
            grantTypes = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
            postLogoutRedirectUris = ["https://{}".format(parameters.vaultFqdn)]
            appType = "OIDC_APP_TYPE_WEB"
            authMethodType = "OIDC_AUTH_METHOD_TYPE_BASIC"
            version = "OIDC_VERSION_1_0"
            devMode = False
            accessTokenType = "OIDC_TOKEN_TYPE_BEARER"
            accessTokenRoleAssertion = True
            idTokenRoleAssertion = True
            idTokenUserinfoAssertion = True
            additionalOrigins = []
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
        writeConnectionSecretToRef = {
            name = "{}-oidc-app-conn".format(oxr.metadata.name)
            namespace = parameters.vaultNamespace
        }
    }
}

_oidcAppConnObserve = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-oidc-app-conn-observe".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-oidc-app-conn-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-oidc-app-conn".format(oxr.metadata.name)
                    namespace = parameters.vaultNamespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_decodedOidcAppClientId = base64.decode(ocds["zitadel-oidc-app-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"]) or ""

# Create Project Roles
_adminRole = {
    apiVersion = "project.zitadel.crossplane.io/v1alpha1"
    kind = "Role"
    metadata = {
        name = "{}-admin-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-admin-role"
        }
    }
    spec = {
        forProvider = {
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            roleKey = parameters.adminRbacGroup
            displayName = "Vault Admins"
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

_userRole = {
    apiVersion = "project.zitadel.crossplane.io/v1alpha1"
    kind = "Role"
    metadata = {
        name = "{}-user-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-user-role"
        }
    }
    spec = {
        forProvider = {
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            roleKey = parameters.userRbacGroup
            displayName = "Vault Users"
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

# Observe Zitadel Human User ID Secret
_zitadelAdminHumanUserIdObserveSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-ahuid-observe-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-ahuid-observe-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.zitadelAdminHumanUserIdRef.name
                    namespace = parameters.zitadelAdminHumanUserIdRef.namespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_zitadelAdminHumanUserId = base64.decode(ocds["zitadel-ahuid-observe-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters.zitadelAdminHumanUserIdRef.key]) or ""

# Create User Grant
_userGrant = {
    apiVersion = "user.zitadel.crossplane.io/v1alpha1"
    kind = "Grant"
    metadata = {
        name = "{}-user-grant".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-user-grant"
        }
    }
    spec = {
        forProvider = {
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            roleKeys = [parameters.adminRbacGroup]
            userId = _zitadelAdminHumanUserId
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

_vaultOidcJwtAuthBackend = {
    apiVersion = "jwt.vault.upbound.io/v1alpha1"
    kind = "AuthBackend"
    metadata = {
        name = "{}-vault-oidc-jwt-auth-backend-object".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-oidc-jwt-auth-backend-object"
        }
    }
    spec = {
        forProvider = {
            path = "oidc"
            description = "Vault oidc auth backend"
            oidcDiscoveryUrl = "https://{}".format(parameters?.zitadelFqdn)
            boundIssuer = "https://{}".format(parameters?.zitadelFqdn)
            oidcClientId = _decodedOidcAppClientId
            oidcClientSecretSecretRef = {
                    name = "{}-oidc-app-conn".format(oxr.metadata.name)
                    namespace = parameters.vaultNamespace
                    key = "attribute.client_secret"
                }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.vaultProviderName
        }
    }
}

_vaultJwtAuthRole = {
    apiVersion = "jwt.vault.upbound.io/v1alpha1"
    kind = "AuthBackendRole"
    metadata = {
        name = "{}-vault-oidc-jwt-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "vault-oidc-jwt-role"
        }
    }
    spec = {
        forProvider = {
            backend = "oidc"
            roleName = parameters?.adminRbacGroup
            boundAudiences = [_decodedOidcAppClientId]
            tokenPolicies = ["vault-admin"]
            oidcScopes = ["openid"]
            userClaim = "sub"
            roleType = "oidc"
            allowedRedirectUris = ["https://{}/ui/vault/auth/oidc/oidc/callback".format(parameters?.vaultFqdn)]
            boundClaims = {
              "{}".format(parameters.oidcProviderGroupClaimPrefix) = "{}:{}".format(ocds["zitadel-project"]?.Resource?.status?.atProvider?.id, parameters?.adminRbacGroup)
            }

        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.vaultProviderName
        }
    }
}

# Add all objects to _items in one line
_items = [
  _observe_org_id_secret
  _project
  _oidcApp
  _oidcAppConnObserve
  _adminRole
  _userRole
  _userGrant
  _vaultOidcJwtAuthBackend
  _vaultJwtAuthRole
  _zitadelAdminHumanUserIdObserveSecret
]
dxr = {
    **oxr
}

items = _items + [dxr]
