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
        labels = {
            "gitlab.mojaloop.io/zitadel-project" = "gitlab-oidc"
        }
    }
    spec = {
        forProvider = {
            name = "gitlab"
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
            name = "gitlab"
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            redirectUris = ["https://{}/users/auth/openid_connect/callback".format(parameters.gitlabFqdn)]
            responseTypes = ["OIDC_RESPONSE_TYPE_CODE"]
            grantTypes = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
            postLogoutRedirectUris = ["https://{}".format(parameters.gitlabFqdn)]
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
            namespace = parameters.gitlabNamespace
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
                    namespace = parameters.gitlabNamespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_oidcAppClientId = base64.decode(ocds["zitadel-oidc-app-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"]) or ""
_oidcAppClientSecret = base64.decode(ocds["zitadel-oidc-app-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_secret"]) or ""


# Create Project Roles
_techopsAdminRole = {
    apiVersion = "project.zitadel.crossplane.io/v1alpha1"
    kind = "Role"
    metadata = {
        name = "{}-techops-admin-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-techops-admin-role"
        }
    }
    spec = {
        forProvider = {
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            roleKey = parameters.adminRbacGroup
            displayName = "Techops Admins"
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

_techopsMaintainerRole = {
    apiVersion = "project.zitadel.crossplane.io/v1alpha1"
    kind = "Role"
    metadata = {
        name = "{}-techops-maintainer-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-techops-maintainer-role"
        }
    }
    spec = {
        forProvider = {
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            roleKey = parameters.maintainerRbacGroup
            displayName = "Techops IaC Maintainers"
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

_techopsUserRole = {
    apiVersion = "project.zitadel.crossplane.io/v1alpha1"
    kind = "Role"
    metadata = {
        name = "{}-techops-user-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-techops-user-role"
        }
    }
    spec = {
        forProvider = {
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            roleKey = parameters.userRbacGroup
            displayName = "Techops Users"
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
            roleKeys = [ocds["zitadel-techops-admin-role"]?.Resource?.status?.atProvider?.roleKey or ""]
            userId = _zitadelAdminHumanUserId
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

# Create Kubernetes Secret
_oidcSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-oidc-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "gitlab-oidc-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.oidcSecretName
                    namespace = parameters.gitlabNamespace
                    labels = {
                        "app.kubernetes.io/part-of" = "gitlab"
                        "gitlab.mojaloop.com/oidc-secret" = "true"
                    }
                }
                type = "Opaque"
                data = {
                    provider = base64.encode("""
{
  "name": "openid_connect",
  "label": "Zitadel",
  "icon": "https://${parameters.zitadelFqdn}/ui/console/assets/icons/favicon-32x32.png",
  "args": {
    "name": "openid_connect",
    "scope": [
      "openid",
      "profile",
      "email",
      "groups"
    ],
    "response_type": "code",
    "issuer": "https://${parameters.zitadelFqdn}",
    "discovery": true,
    "client_auth_method": "query",
    "client_options": {
      "identifier": "${_oidcAppClientId}",
      "secret": "${_oidcAppClientSecret}",
      "host": "${parameters.zitadelFqdn}",
      "redirect_uri": "https://${parameters.gitlabFqdn}/users/auth/openid_connect/callback",
      "authorization_endpoint": "https://${parameters.zitadelFqdn}/oauth/v2/authorize",
      "token_endpoint": "https://${parameters.zitadelFqdn}/oauth/v2/token",
      "userinfo_endpoint": "https://${parameters.zitadelFqdn}/oidc/v1/userinfo",
      "jwks_uri": "https://${parameters.zitadelFqdn}/oauth/v2/keys",
      "gitlab": {
        "groups_attribute": "${parameters.oidcProviderGroupClaimPrefix}",
        "admin_groups": ["${ocds["zitadel-project"]?.Resource?.status?.atProvider?.id}:${parameters.adminRbacGroup}"]
      }
    }
  }
}""")
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

# Add all objects to _items in one line
_items = [_observe_org_id_secret, _project, _zitadelAdminHumanUserIdObserveSecret, _oidcAppConnObserve, _oidcApp, _techopsAdminRole, _techopsMaintainerRole, _techopsUserRole, _userGrant, _oidcSecret]

dxr = {
    **oxr
}

items = _items + [dxr]
