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
            name = "argocd"
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
            name = "argocd"
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            redirectUris = ["https://{}/auth/callback".format(parameters.argocdFqdn)]
            responseTypes = ["OIDC_RESPONSE_TYPE_CODE"]
            grantTypes = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
            postLogoutRedirectUris = ["https://{}".format(parameters.argocdFqdn)]
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
            namespace = parameters.argocdNamespace
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
                    namespace = parameters.argocdNamespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_oidcAppClientId = ocds["zitadel-oidc-app-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"] or ""
_oidcAppClientSecret = ocds["zitadel-oidc-app-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_secret"] or ""

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
            displayName = "ArgoCd Admins"
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
            displayName = "ArgoCd Users"
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

# Create Kubernetes Secret
_oidcSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-oidc-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "argo-oidc-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-oidc-secret".format(oxr.metadata.name)
                    namespace = parameters.argocdNamespace
                    labels = {
                        "app.kubernetes.io/part-of" = "argocd"
                        "reloader" = "enabled"
                    }
                }
                data = {
                    oidc_client_id = _oidcAppClientId
                    oidc_client_secret = _oidcAppClientSecret
                }
                type = "Opaque"
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

# Create RBAC ConfigMap
_rbacConfigMap = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-rbac-cm".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "argocd-rbac-cm"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = "argocd-rbac-cm"
                    namespace = parameters.argocdNamespace
                }
                data = {
                    "policy.csv" = "g, {}:{}, role:admin\ng, {}:{}, role:readonly".format(
                        ocds["zitadel-project"]?.Resource?.status?.atProvider?.id,
                        parameters.adminRbacGroup,
                        ocds["zitadel-project"]?.Resource?.status?.atProvider?.id,
                        parameters.userRbacGroup
                    )
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

# Create OIDC ConfigMap
_oidcConfigMap = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-oidc-cm".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "argocd-cm"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ConfigMap"
                metadata = {
                    name = "argocd-cm"
                    namespace = parameters.argocdNamespace
                }
                data = {
                    "oidc.config" = """name: Zitadel
issuer: https://${parameters.zitadelFqdn}
clientID: $${oxr.metadata.name}-oidc-secret:oidc_client_id
clientSecret: $${oxr.metadata.name}-oidc-secret:oidc_client_secret
requestedScopes:
  - openid
  - profile
  - email
  - groups
logoutURL: https://${parameters.zitadelFqdn}/oidc/v1/end_session"""
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
_items = [_observe_org_id_secret, _project, _oidcApp, _oidcAppConnObserve, _adminRole, _userRole, _userGrant, _oidcSecret, _rbacConfigMap, _oidcConfigMap, _zitadelAdminHumanUserIdObserveSecret]

dxr = {
    **oxr
}

items = _items + [dxr]
