import base64

# Read the XR and the Observed Connection Details (OCDs)
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters

# --- 1. Infrastructure Helpers (Org & Admin ID Observation) ---
_observe_org_id_secret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-org-id-observe".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-org-id-secret-observe"
        }
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {
                name = parameters.organizationIdSecretRef?.name
                namespace = parameters.organizationIdSecretRef?.namespace
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

_zitadelAdminHumanUserIdObserve = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-ahuid-obs".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-admin-user-id-observe"
        }
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {
                name = parameters.zitadelAdminHumanUserIdRef.name
                namespace = parameters.zitadelAdminHumanUserIdRef.namespace
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

# --- Extract Data from OCDs ---
_orgId = base64.decode(ocds["zitadel-org-id-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?[parameters.organizationIdSecretRef?.key]) or ""
_zitadelAdminHumanUserId = base64.decode(ocds["zitadel-admin-user-id-observe"]?.Resource?.status?.atProvider?.manifest?.data?[parameters.zitadelAdminHumanUserIdRef.key]) or ""

# --- 2. Project & Apps ---
_project = {
    apiVersion = "zitadel.zitadel.crossplane.io/v1alpha1"
    kind = "Project"
    metadata = {
        name = "{}-project".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-nb-project"
        }
    }
    spec = {
        forProvider = {
            name = "Netbird"
            orgId = _orgId
            projectRoleAssertion = True
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

_project_id = ocds["zitadel-nb-project"]?.Resource?.status?.atProvider?.id or ""

_oidcApp = {
    apiVersion = "application.zitadel.crossplane.io/v1alpha1"
    kind = "Oidc"
    metadata = {
        name = "{}-oidc-app".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-nb-oidc-app"
        }
    }
    spec = {
        forProvider = {
            name = "netbird"
            projectId = _project_id
            orgId = _orgId
            redirectUris = [
                "https://{}/nb-auth".format(parameters.netbirdFqdn)
                "https://{}/nb-silent-auth".format(parameters.netbirdFqdn)
            ]
            responseTypes = ["OIDC_RESPONSE_TYPE_CODE"]
            grantTypes = [
                "OIDC_GRANT_TYPE_AUTHORIZATION_CODE"
                "OIDC_GRANT_TYPE_REFRESH_TOKEN"
            ]
            postLogoutRedirectUris = ["https://{}/".format(parameters.netbirdFqdn)]
            appType = "OIDC_APP_TYPE_USER_AGENT"
            authMethodType = "OIDC_AUTH_METHOD_TYPE_NONE"
            version = "OIDC_VERSION_1_0"
            devMode = False
            accessTokenType = "OIDC_TOKEN_TYPE_JWT"
            accessTokenRoleAssertion = True
        }
        writeConnectionSecretToRef = {
            name = "{}-oidc-app-conn".format(oxr.metadata.name)
            namespace = parameters.netbirdNamespace
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

_cliOidcApp = {
    apiVersion = "application.zitadel.crossplane.io/v1alpha1"
    kind = "Oidc"
    metadata = {
        name = "{}-cli-oidc-app".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-nb-cli-oidc-app"
        }
    }
    spec = {
        forProvider = {
            name = "Netbird-Cli"
            projectId = _project_id
            orgId = _orgId
            redirectUris = [
                "http://localhost:53000/"
                "http://localhost:54000/"
            ]
            responseTypes = ["OIDC_RESPONSE_TYPE_CODE"]
            grantTypes = [
                "OIDC_GRANT_TYPE_AUTHORIZATION_CODE"
                "OIDC_GRANT_TYPE_DEVICE_CODE"
                "OIDC_GRANT_TYPE_REFRESH_TOKEN"
            ]
            postLogoutRedirectUris = ["http://localhost:53000/"]
            appType = "OIDC_APP_TYPE_USER_AGENT"
            authMethodType = "OIDC_AUTH_METHOD_TYPE_NONE"
            version = "OIDC_VERSION_1_0"
            devMode = True
            accessTokenType = "OIDC_TOKEN_TYPE_JWT"
            accessTokenRoleAssertion = True
        }
        writeConnectionSecretToRef = {
            name = "{}-cli-oidc-app-conn".format(oxr.metadata.name)
            namespace = parameters.netbirdNamespace
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

# --- 3. Machine Users ---
_zitadelMachineUser = {
    apiVersion = "machine.zitadel.crossplane.io/v1alpha1"
    kind = "User"
    metadata = {
        name = "{}-nb-service-user".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-nb-service-user"
        }
    }
    spec = {
        forProvider = {
            userName = "netbird"
            name = "netbird"
            description = "Netbird Service Account for IDP management"
            orgId = _orgId
            accessTokenType = "ACCESS_TOKEN_TYPE_JWT"
            withSecret = True
        }
        writeConnectionSecretToRef = {
            name = "{}-service-user-creds".format(oxr.metadata.name)
            namespace = parameters.netbirdNamespace
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

_netbirdApiAdmin = {
    apiVersion = "machine.zitadel.crossplane.io/v1alpha1"
    kind = "User"
    metadata = {
        name = "{}-api-admin".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-netbird-api-admin"
        }
    }
    spec = {
        forProvider = {
            userName = "netbird-api-admin"
            name = "netbird-api-admin"
            description = "Netbird API admin user"
            orgId = _orgId
            accessTokenType = "ACCESS_TOKEN_TYPE_JWT"
            withSecret = True
        }
        writeConnectionSecretToRef = {
            name = "{}-api-admin-creds".format(oxr.metadata.name)
            namespace = parameters.netbirdNamespace
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

# --- 4. Roles & Grants ---
_techopsAdminRole = {
    apiVersion = "project.zitadel.crossplane.io/v1alpha1"
    kind = "Role"
    metadata = {
        name = "{}-techops-admin".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-nb-techops-admin-role"
        }
    }
    spec = {
        forProvider = {
            projectId = _project_id
            orgId = _orgId
            roleKey = parameters.adminRbacGroup
            displayName = "Techops Admin"
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

_techopsUserRole = {
    apiVersion = "project.zitadel.crossplane.io/v1alpha1"
    kind = "Role"
    metadata = {
        name = "{}-techops-user".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-nb-techops-user-role"
        }
    }
    spec = {
        forProvider = {
            projectId = _project_id
            orgId = _orgId
            roleKey = parameters.userRbacGroup
            displayName = "Techops User"
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}



_adminHumanGrant = {
    apiVersion = "user.zitadel.crossplane.io/v1alpha1"
    kind = "Grant"
    metadata = {
        name = "{}-admin-human-grant".format(oxr.metadata.name)
    }
    spec = {
        forProvider = {
            projectId = _project_id
            orgId = _orgId
            userId = _zitadelAdminHumanUserId
            roleKeys = [
                ocds["zitadel-nb-techops-admin-role"]?.Resource?.status?.atProvider?.roleKey or ""
            ]
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

# Extract the observed role keys
_admin_key = ocds["zitadel-nb-techops-admin-role"]?.Resource?.status?.atProvider?.roleKey
_user_key = ocds["zitadel-nb-techops-user-role"]?.Resource?.status?.atProvider?.roleKey

# 2. Define the conditional list logic
# We check if both are not None and have a length > 0
_role_keys_list = [_admin_key, _user_key] if _admin_key and _user_key else [""]

_apiAdminGrant = {
    apiVersion = "user.zitadel.crossplane.io/v1alpha1"
    kind = "Grant"
    metadata = {
        name = "{}-api-admin-grant".format(oxr.metadata.name)
    }
    spec = {
        forProvider = {
            projectId = _project_id
            orgId = _orgId
            userId = ocds["zitadel-netbird-api-admin"]?.Resource?.status?.atProvider?.id or ""
            roleKeys = _role_keys_list
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

# --- 5. The "Output Secret" & Observations ---
_outputSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-consolidated-outputs".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-outputs-secret"
        }
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {
                name = parameters.netbirdPreConfigOutputSecret
                namespace = parameters.netbirdNamespace
            }
            type = "Opaque"
            data = {
                netbird_project_id = base64.encode(_project_id or "")
                netbird_client_id = ocds["zitadel-nb-oidc-app-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"] or ""
                netbird_cli_client_id = ocds["zitadel-nb-cli-oidc-app-conn-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"] or ""
                netbird_service_user_client_id = ocds["zitadel-nb-service-user-creds-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"] or ""
                netbird_service_user_client_secret = ocds["zitadel-nb-service-user-creds-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_secret"] or ""
                netbird_api_admin_user_client_id = ocds["zitadel-api-admin-creds-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_id"] or ""
                netbird_api_admin_user_client_secret = ocds["zitadel-api-admin-creds-observe"]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_secret"] or ""
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

# Observations Loop with unique keys
_obsNames = [
    {
        "key" = "zitadel-nb-oidc-app-conn"
        "suffix" = "oidc-app-conn"
    }
    {
        "key" = "zitadel-nb-cli-oidc-app-conn"
        "suffix" = "cli-oidc-app-conn"
    }
    {
        "key" = "zitadel-nb-service-user-creds"
        "suffix" = "service-user-creds"
    }
    {
        "key" = "zitadel-api-admin-creds"
        "suffix" = "api-admin-creds"
    }
]

_observations = [
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-{}-obs".format(oxr.metadata.name, item.suffix)
            annotations = {
                "krm.kcl.dev/composition-resource-name" = "{}-observe".format(item.key)
            }
        }
        spec = {
            forProvider.manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-{}".format(oxr.metadata.name, item.suffix)
                    namespace = parameters.netbirdNamespace
                }
            }
            managementPolicies = ["Observe"]
            providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
        }
    } for item in _obsNames
]

# Final Items
_items = [
    _observe_org_id_secret
    _zitadelAdminHumanUserIdObserve
    _project
    _oidcApp
    _cliOidcApp
    _zitadelMachineUser
    _netbirdApiAdmin
    _techopsAdminRole
    _techopsUserRole
    _adminHumanGrant
    _apiAdminGrant
    _outputSecret
]

items = _items + _observations + [oxr]