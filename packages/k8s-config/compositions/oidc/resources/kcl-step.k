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
            name = "k8s"
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
            name = "k8s-cli"
            projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id
            orgId = _orgId
            redirectUris = ["http://localhost:8000"]
            responseTypes = ["OIDC_RESPONSE_TYPE_CODE"]
            grantTypes = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
            postLogoutRedirectUris = ["http://localhost:8000"]
            appType = "OIDC_APP_TYPE_NATIVE"
            authMethodType = "OIDC_AUTH_METHOD_TYPE_NONE"
            version = "OIDC_VERSION_1_0"
            devMode = False
            accessTokenType = "OIDC_TOKEN_TYPE_JWT"
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
            namespace = parameters.k8sNamespace
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
                    namespace = parameters.k8sNamespace
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
            displayName = "Techops Admin"
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
            displayName = "Techops User"
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

# Create cluster role binding
_k8sAdminRoleBinding = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-k8s-admin-user-binding".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "k8s-admin-user-binding"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "rbac.authorization.k8s.io/v1"
                kind = "ClusterRoleBinding"
                metadata = {
                    name = "k8s-admin"
                }
                roleRef = {
                    apiGroup = "rbac.authorization.k8s.io"
                    kind = "ClusterRole"
                    name = "cluster-admin"
                }
                subjects = [
                    {
                        kind = "Group"
                        name = "{}:{}".format(
                            ocds["zitadel-project"]?.Resource?.status?.atProvider?.id,
                            parameters.adminRbacGroup
                        )
                    }
                ]
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}


# Create user cluster role
_k8sUserRole = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-k8s-user".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "k8s-user"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "rbac.authorization.k8s.io/v1" // Standard API version for ClusterRole
                kind = "ClusterRole"
                metadata = {
                    name = "k8s-user"
                }
                rules = [
                    {
                        apiGroups = [""]
                        resources = ["*"]
                        verbs = ["get", "list", "watch"]
                    }
                ]
            }
        }
    }
}

# Create user cluster role binding
_k8sUserRoleBinding = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-k8s-user-binding".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "k8s-user-binding"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "rbac.authorization.k8s.io/v1"
                kind = "ClusterRoleBinding"
                metadata = {
                    name = "k8s-user"
                }
                roleRef = {
                    apiGroup = "rbac.authorization.k8s.io"
                    kind = "ClusterRole"
                    name = "k8s-user"
                }
                subjects = [
                    {
                        kind = "Group"
                        name = "{}:{}".format(
                            ocds["zitadel-project"]?.Resource?.status?.atProvider?.id,
                            parameters.userRbacGroup
                        )
                    }
                ]
            }
        }
    }
}


# Add all objects to _items in one line
_items = [_observe_org_id_secret, _project, _oidcApp, _oidcAppConnObserve, _adminRole, _userRole, _userGrant, _k8sAdminRoleBinding, _k8sUserRole, _k8sUserRoleBinding, _zitadelAdminHumanUserIdObserveSecret]

dxr = {
    **oxr
}

items = _items + [dxr]
