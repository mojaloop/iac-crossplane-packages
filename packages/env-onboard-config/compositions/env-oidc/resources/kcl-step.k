import base64
import json
import crypto

# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

# Observe Zitadel Org ID Secret
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

# Create Zitadel Project for the Environment
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
            name = parameters.envName
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

_projectId = ocds["zitadel-project"]?.Resource?.status?.atProvider?.id or ""

# Function to define OIDC Application
_define_oidc_app = lambda name, app_name, redirect_uris, logout_uris, dev_mode, app_type, auth_method, access_token_type = "OIDC_TOKEN_TYPE_BEARER" -> any {
    {
        apiVersion = "application.zitadel.crossplane.io/v1alpha1"
        kind = "Oidc"
        metadata = {
            name = "{}-{}-oidc".format(oxr.metadata.name, name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "{}-oidc".format(name)
            }
        }
        spec = {
            forProvider = {
                name = app_name
                projectId = _projectId
                orgId = _orgId
                redirectUris = redirect_uris
                responseTypes = ["OIDC_RESPONSE_TYPE_CODE"]
                grantTypes = ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE", "OIDC_GRANT_TYPE_REFRESH_TOKEN"] if app_type == "OIDC_APP_TYPE_WEB" else ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE"]
                postLogoutRedirectUris = logout_uris
                appType = app_type
                authMethodType = auth_method
                version = "OIDC_VERSION_1_0"
                devMode = dev_mode
                accessTokenType = access_token_type
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
                name = "{}-{}-oidc-conn".format(oxr.metadata.name, name)
                namespace = parameters.envName
            }
        }
    }
}

# 1. Grafana OIDC App
_grafana_oidc = _define_oidc_app(
    "grafana",
    "{}-grafana".format(parameters.envName),
    ["https://{}/login/generic_oauth".format(parameters.grafanaFqdn)],
    ["https://{}".format(parameters.grafanaFqdn)],
    False,
    "OIDC_APP_TYPE_WEB",
    "OIDC_AUTH_METHOD_TYPE_BASIC"
)

# 2. Vault UI OIDC App
_vault_oidc = _define_oidc_app(
    "vault",
    "{}-vault-ui".format(parameters.envName),
    ["https://{}/ui/vault/auth/oidc/oidc/callback".format(parameters.vaultFqdn)],
    ["https://{}/ui".format(parameters.vaultFqdn)],
    False,
    "OIDC_APP_TYPE_WEB",
    "OIDC_AUTH_METHOD_TYPE_BASIC"
)

# 3. ArgoCD OIDC App
_argocd_oidc = _define_oidc_app(
    "argocd",
    "{}-argocd".format(parameters.envName),
    ["https://{}/auth/callback".format(parameters.argocdFqdn)],
    ["https://{}".format(parameters.argocdFqdn)],
    False,
    "OIDC_APP_TYPE_WEB",
    "OIDC_AUTH_METHOD_TYPE_BASIC"
)

# 4. Addons OIDC App (Dev Mode True)
_addons_oidc = _define_oidc_app(
    "addons",
    "{}-addons".format(parameters.envName),
    ["https://*.{}/**/*".format(parameters.addonsDomain)],
    ["https://*.{}/**/*".format(parameters.addonsDomain)],
    True,
    "OIDC_APP_TYPE_WEB",
    "OIDC_AUTH_METHOD_TYPE_BASIC"
)

# 5. K8s CLI OIDC App (Native)
_k8s_cli_oidc = _define_oidc_app(
    "k8s-cli",
    "{}-k8s-cli".format(parameters.envName),
    ["http://localhost:8000"],
    ["http://localhost:8000"],
    False,
    "OIDC_APP_TYPE_NATIVE",
    "OIDC_AUTH_METHOD_TYPE_NONE",
    "OIDC_TOKEN_TYPE_JWT"
)


# Vault KV Secrets (Using generic.vault.upbound.io/v1alpha1 Secret)
_create_vault_kv_secret = lambda name, mount, path, secret_ref_name -> any {
    {
        apiVersion = "generic.vault.upbound.io/v1alpha1"
        kind = "Secret"
        metadata = {
            name = "{}-{}".format(oxr.metadata.name, name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "vault-secret-{}".format(name)
            }
        }
        spec = {
            forProvider = {
                path = "{}/{}".format(mount, path)
                dataJsonSecretRef = {
                    key = "value"
                    name = secret_ref_name
                    namespace = parameters.envName
                }
                deleteAllVersions = True
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.vaultProviderName
            }
        }
    }
}

# Helper to observe Connection Secrets for OIDC Apps to get Client ID/Secret
_observe_oidc_secret = lambda name -> any {
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-{}".format(oxr.metadata.name, name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "{}-oidc-conn-observe".format(name)
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "{}-{}-oidc-conn".format(oxr.metadata.name, name)
                        namespace = parameters.envName
                    }
                }
            }
            managementPolicies = ["Observe"]
            providerConfigRef = {
                name = spec.providerConfigsRef.kubernetesProviderName
            }
        }
    }
}
_grafana_secret_obs = _observe_oidc_secret("grafana")
_vault_secret_obs = _observe_oidc_secret("vault")
_argocd_secret_obs = _observe_oidc_secret("argocd")
_addons_secret_obs = _observe_oidc_secret("addons")
_k8s_cli_secret_obs = _observe_oidc_secret("k8s-cli")

_get_secret_data = lambda name, key -> str {
    base64.decode(ocds["{}-oidc-conn-observe".format(name)]?.Resource?.status?.atProvider?.manifest?.data?[key]) or ""
}

# Create Kubernetes Secret to hold the sensitive data
_create_k8s_secret = lambda name, data -> any {
    {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-k8s-secret-{}".format(oxr.metadata.name, name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "k8s-secret-{}".format(name)
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Secret"
                    metadata = {
                        name = "{}-{}".format(oxr.metadata.name, name)
                        namespace = parameters.envName
                    }
                    stringData = {
                        value = data
                    }
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.kubernetesProviderName
            }
        }
    }
}




_grafana_id = _get_secret_data("grafana", "attribute.client_id")
_grafana_secret = _get_secret_data("grafana", "attribute.client_secret")
_vault_id = _get_secret_data("vault", "attribute.client_id")
_vault_secret = _get_secret_data("vault", "attribute.client_secret")
_argocd_id = _get_secret_data("argocd", "attribute.client_id")
_argocd_secret = _get_secret_data("argocd", "attribute.client_secret")
_addons_id = _get_secret_data("addons", "attribute.client_id")
_addons_secret = _get_secret_data("addons", "attribute.client_secret")
_k8s_id = _get_secret_data("k8s-cli", "attribute.client_id")

_k8s_secrets = []
_vault_secrets = []

# Helper lambdas to create individual secrets
_make_k8s_secret = lambda name: str, val: str -> any {
    _create_k8s_secret(name, "{\"value\": \"" + val + "\"}")
}

_make_vault_secret = lambda name: str, path: str -> any {
    _create_vault_kv_secret(name, parameters.vaultKvPath, path, "{}-{}".format(oxr.metadata.name, name))
}

if _grafana_id != "":
    _k8s_secrets += [_make_k8s_secret("grafana-id", _grafana_id)]
    _vault_secrets += [_make_vault_secret("grafana-id", "{}/grafana_oidc_client_id".format(parameters.envName))]

if _grafana_secret != "":
    _k8s_secrets += [_make_k8s_secret("grafana-secret", _grafana_secret)]
    _vault_secrets += [_make_vault_secret("grafana-secret", "{}/grafana_oidc_client_secret".format(parameters.envName))]

if _vault_id != "":
    _k8s_secrets += [_make_k8s_secret("vault-id", _vault_id)]
    _vault_secrets += [_make_vault_secret("vault-id", "{}/vault_oidc_client_id".format(parameters.envName))]

if _vault_secret != "":
    _k8s_secrets += [_make_k8s_secret("vault-secret", _vault_secret)]
    _vault_secrets += [_make_vault_secret("vault-secret", "{}/vault_oidc_client_secret".format(parameters.envName))]

if _argocd_id != "":
    _k8s_secrets += [_make_k8s_secret("argocd-id", _argocd_id)]
    _vault_secrets += [_make_vault_secret("argocd-id", "{}/argocd_oidc_client_id".format(parameters.envName))]

if _argocd_secret != "":
    _k8s_secrets += [_make_k8s_secret("argocd-secret", _argocd_secret)]
    _vault_secrets += [_make_vault_secret("argocd-secret", "{}/argocd_oidc_client_secret".format(parameters.envName))]

if _addons_id != "":
    _k8s_secrets += [_make_k8s_secret("addons-id", _addons_id)]
    _vault_secrets += [_make_vault_secret("addons-id", "{}/addons_oidc_client_id".format(parameters.envName))]

if _addons_secret != "":
    _k8s_secrets += [_make_k8s_secret("addons-secret", _addons_secret)]
    _vault_secrets += [_make_vault_secret("addons-secret", "{}/addons_oidc_client_secret".format(parameters.envName))]

if _k8s_id != "":
    _k8s_secrets += [_make_k8s_secret("k8s-id", _k8s_id)]
    _vault_secrets += [_make_vault_secret("k8s-id", "{}/kubernetes_oidc_client_id".format(parameters.envName))]



# Gitlab Project Variables
_create_gitlab_variable = lambda name, key, value, env -> any {
    {
        apiVersion = "projects.gitlab.crossplane.io/v1alpha1"
        kind = "Variable"
        metadata = {
            name = "{}-{}".format(oxr.metadata.name, name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "gitlab-variable-{}".format(name)
            }
        }
        spec = {
            forProvider = {
                key = key
                value = value
                protected = False
                masked = False
                projectIdSelector = {
                    matchLabels = {
                    "gitlab.mojaloop.com/project-name" = env
                    }
                }            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.gitlabProviderName
            }
        }
    }
}

_gitlab_variables = []

_gitlab_variables = [
    _create_gitlab_variable("k8s-oidc-admin-group", "KUBERNETES_OIDC_K8S_ADMIN_GROUP", "{}:{}".format(_projectId, parameters.k8sAdminRbacGroup), parameters.envName)
    _create_gitlab_variable("k8s-oidc-user-group", "KUBERNETES_OIDC_K8S_USER_GROUP", "{}:{}".format(_projectId, parameters.k8sUserRbacGroup), parameters.envName)
]

if parameters.netbirdOperatorManagementUrl:
    _gitlab_variables += [_create_gitlab_variable("netbird-mgmt-url", "netbird_operator_management_url", parameters.netbirdOperatorManagementUrl, parameters.envName)]

if parameters.netbirdOperatorApiKeyVaultPath:
    _gitlab_variables += [_create_gitlab_variable("netbird-api-key-path", "netbird_operator_api_key_vault_path", parameters.netbirdOperatorApiKeyVaultPath, parameters.envName)]

if parameters.netbirdSetupKeyVaultPath:
    _gitlab_variables += [_create_gitlab_variable("netbird-setup-key-path", "netbird_setup_key_vault_path", parameters.netbirdSetupKeyVaultPath, parameters.envName)]


# Roles and Grants
_create_role = lambda role_key, display_name -> any {
    _safe_name = role_key.replace("_", "-")
    {
        apiVersion = "project.zitadel.crossplane.io/v1alpha1"
        kind = "Role"
        metadata = {
            name = "{}-role-{}".format(oxr.metadata.name, _safe_name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "role-{}".format(_safe_name)
            }
        }
        spec = {
            forProvider = {
                projectId = _projectId
                orgId = _orgId
                roleKey = role_key
                displayName = display_name
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec.providerConfigsRef.zitadelProviderName
            }
        }
    }
}

_roles = [
    _create_role(parameters.grafanaAdminRbacGroup, "Grafana Admins"),
    _create_role(parameters.grafanaUserRbacGroup, "Grafana Users"),
    _create_role(parameters.vaultAdminRbacGroup, "Vault Admins"),
    _create_role(parameters.vaultUserRbacGroup, "Vault Users"),
    _create_role(parameters.argocdAdminRbacGroup, "Argocd Admins"),
    _create_role(parameters.argocdUserRbacGroup, "Argocd Users"),
    _create_role("addons-administrators", "Addons Admins"), # Default values from TF
    _create_role("addons-users", "Addons Users"),           # Default values from TF
    _create_role(parameters.k8sAdminRbacGroup, "Techops Admin"),
    _create_role(parameters.k8sUserRbacGroup, "Techops User")
]

# Admin User Grant
_zitadel_ahuid_observe_secret = {
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

_admin_user_grant = {
    apiVersion = "user.zitadel.crossplane.io/v1alpha1"
    kind = "Grant"
    metadata = {
        name = "{}-admin-user-grant".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "admin-user-grant"
        }
    }
    spec = {
        forProvider = {
            projectId = _projectId
            orgId = _orgId
            roleKeys = [
                parameters.argocdAdminRbacGroup,
                parameters.vaultAdminRbacGroup,
                parameters.grafanaAdminRbacGroup,
                parameters.k8sAdminRbacGroup,
                "addons-administrators"
            ]
            userId = _zitadelAdminHumanUserId
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

# Observe Nexus Readonly Password Secret
_observe_nexus_readonly_password = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-nexus-readonly-password-observe".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "nexus-readonly-password-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.nexusReadonlyPasswordSecretName if parameters.nexusReadonlyPasswordSecretName else "external-docker-nexus-secret"
                    namespace = parameters.nexusReadonlyPasswordSecretNamespace if parameters.nexusReadonlyPasswordSecretNamespace else "vault"
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_nexusReadonlyPasswordData = ocds["nexus-readonly-password-observe"]?.Resource?.status?.atProvider?.manifest?.data or {}
_nexusReadonlyPassword = base64.decode(_nexusReadonlyPasswordData["external-docker-nexus-password"]) if "external-docker-nexus-password" in _nexusReadonlyPasswordData else ""

# Observe Registry Mirror Readonly Password Secret
_observe_registry_mirror_readonly_password = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-registry-mirror-readonly-password-observe".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "registry-mirror-readonly-password-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.registryMirrorReadonlyPasswordSecretName if parameters.registryMirrorReadonlyPasswordSecretName else "external-docker-harbor-secret"
                    namespace = parameters.registryMirrorReadonlyPasswordSecretNamespace if parameters.registryMirrorReadonlyPasswordSecretNamespace else "vault"
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }
}

_registryMirrorReadonlyPasswordData = ocds["registry-mirror-readonly-password-observe"]?.Resource?.status?.atProvider?.manifest?.data or {}
_registryMirrorReadonlyPassword = base64.decode(_registryMirrorReadonlyPasswordData["external-docker-harbor-password"]) if "external-docker-harbor-password" in _registryMirrorReadonlyPasswordData else ""

_registry_k8s_secrets = []
_registry_vault_secrets = []

if _nexusReadonlyPassword != "":
    _registry_k8s_secrets += [_create_k8s_secret("nexus-readonly-password", '{"value": "' + _nexusReadonlyPassword + '"}')]
    _registry_vault_secrets += [_create_vault_kv_secret(
        "nexus-readonly-password",
        parameters.vaultKvPath,
        "{}/nexus_readonly_password".format(parameters.envName),
        "{}-nexus-readonly-password".format(oxr.metadata.name)
    )]

if _registryMirrorReadonlyPassword != "":
    _registry_k8s_secrets += [_create_k8s_secret("registry-mirror-readonly-password", '{"value": "' + _registryMirrorReadonlyPassword + '"}')]
    _registry_vault_secrets += [_create_vault_kv_secret(
        "registry-mirror-readonly-password",
        parameters.vaultKvPath,
        "{}/registry_mirror_readonly_password".format(parameters.envName),
        "{}-registry-mirror-readonly-password".format(oxr.metadata.name)
    )]

# Items assembly
# Netbird Project ID Observation (Assuming it's stored in a secret similar to Org ID)
# If not, we might need to pass it as a parameter explicitly or skip it if unavailable.
# For now, I'll add a placeholder comment or skip it as it requires external info not guaranteed in the current setup.
# The user can enable it if they provide the Netbird Project ID secret reference.

_items = [
    _observe_org_id_secret,
    _project,
    _grafana_oidc,
    _vault_oidc,
    _argocd_oidc,
    _addons_oidc,
    _k8s_cli_oidc,
    _grafana_secret_obs,
    _vault_secret_obs,
    _argocd_secret_obs,
    _addons_secret_obs,
    _k8s_cli_secret_obs,
    _observe_nexus_readonly_password,
    _observe_registry_mirror_readonly_password,
    _zitadel_ahuid_observe_secret,
    _admin_user_grant
] + _roles + _vault_secrets + _k8s_secrets + _registry_vault_secrets + _registry_k8s_secrets + _gitlab_variables

# Return structure
items = _items + [oxr]
