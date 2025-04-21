# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

readyBasedOnConditions = lambda o: any -> bool {
    # Get conditions directly from status
    conditions = o?.Resource?.status?.conditions or []
    # Simply check if all conditions are True
    len(conditions) > 0 and all_true([c.status == "True" for c in conditions])
}

_zitadel_project_id_secret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-project-id-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-project-id-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.zitadelProjectIdSecret.name
                    namespace = parameters.zitadelProjectIdSecret.namespace
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec?.providerConfigsRef?.ccK8sProviderName
        }
    }
}

zitadel_project_id = ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or ""] or ""
admin_group_name = "{}:{}".format(zitadel_project_id, parameters.groupNames.admin)
external_access_group_name = "{}:{}".format(zitadel_project_id, parameters.groupNames.externalAccess)

_external_access_group = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbGroup"
    metadata = {
        name = "{}-external-access-group".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "external-access-group"
            "crossplane.io/external-name": external_access_group_name
        }
    }
    spec = {
        forProvider = {
            name = external_access_group_name
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        managementPolicies = ["Observe"]
    }
}
# Kubernetes Group
_kubernetes_group = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbGroup"
    metadata = {
        name = "{}-kubernetes-group".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "kubernetes-group"
        }
    }
    spec = {
        forProvider = {
            name = parameters.groupNames.kubeapiResourceGroup
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        managementPolicies = spec?.managementPolicies
    }
}
# NB Service User
_service_user = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbUser"
    metadata = {
        name = "{}-service-user".format(parameters.serviceUserName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "service-user"
        }
    }
    spec = {
        forProvider = {
            name = "{}-service-user".format(parameters.serviceUserName)
            is_service_user: True
            role: "admin"
            auto_groups: []
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        managementPolicies = spec?.managementPolicies
    }
}
### Access Token
# NB Service User Access Token
if parameters.accessToken.destinationType == "local":
    _access_token_secret_name = "nb-operator-api-key"
    _access_token_secret_namespace = oxr.metadata.namespace if oxr.metadata.namespace else "crossplane-system"
else:
    _access_token_secret_name = "{}-access-token".format(oxr.metadata.name)
    _access_token_secret_namespace = oxr.metadata.namespace if oxr.metadata.namespace else "crossplane-system"
_access_token = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbAccessToken"
    metadata = {
        name = "{}-access-token".format(parameters.serviceUserName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "access-token"
        }
    }
    spec = {
        forProvider = {
            name = "{}-access-token".format(parameters.serviceUserName)
            user_name: ocds["service-user"]?.Resource?.status?.atProvider?.name or ""
            expires_in: parameters.accessTokenExpiresInDays
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        writeConnectionSecretToRef = {
            name = _access_token_secret_name
            namespace = _access_token_secret_namespace
        }
        managementPolicies = spec?.managementPolicies
    }
}
# Access Token Secret Copy
if parameters.accessToken.destinationType == "sc":
    # Netbird Namespace
    _sc_netbird_namespace = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-ns".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "sc-netbird-namespace"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "Namespace"
                    metadata = {
                        name = parameters.operatorNamespace
                    }
                }
            }
            managementPolicies = spec.managementPolicies
            providerConfigRef = {
                name = spec?.providerConfigsRef?.scK8sProviderName
            }
        }
    }

    _sc_access_token_secret_copy = {
        apiVersion = "utils.mojaloop.io/v1alpha1"
        kind = "XObjectSyncer"
        metadata = {
            name = "{}-secret".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "sc-access-token-secret-copy"
            }
        }
        spec = {
            parameters = {
                objectType = "Secret"
                source = {
                    name = ocds["access-token"]?.Resource?.spec?.writeConnectionSecretToRef?.name or ""
                    namespace = ocds["access-token"]?.Resource?.spec?.writeConnectionSecretToRef?.namespace or ""
                }
                destination = {
                    name = "nb-operator-api-key"
                    namespace = "nb-op"
                    secretType = "Opaque"
                }
            }
            providerConfigsRef = {
                sourceK8sProviderName = spec?.providerConfigsRef?.ccK8sProviderName
                destinationK8sProviderName = spec?.providerConfigsRef?.scK8sProviderName
            }
            managementPolicies = spec?.managementPolicies
        }
    }

# elif parameters.accessToken.destinationType == "tenantVault":
#     # TODO: Implement tenant vault stuff
_k8s_policy = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbPolicy"
    metadata = {
        name = "{}-k8s-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "k8s-policy"
        }
    }
    spec = {
        forProvider = {
            name = "{}-k8s-policy".format(oxr.metadata.name)
            enabled = True
            description = "Policy for connecting to kubeapi for {}".format(oxr.metadata.name)
            rules = [
                {
                    action = "accept"
                    bidirectional = False
                    description = "k8s accept"
                    name = "k8s-accept-rule"
                    enabled = True
                    destinations = [
                        {
                            id = ocds["kubernetes-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    sources = [
                        {
                            id = ocds["external-access-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    port_ranges = [
                        {
                            start = 443
                            end = 443
                        }
                    ]
                    protocol = "tcp"
                }
            ]
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        managementPolicies = spec?.managementPolicies
    }
}
# Add the resources to the items list
_items += [
    _zitadel_project_id_secret
    _external_access_group
    _kubernetes_group
    _service_user
    _access_token
    _k8s_policy
]

if parameters.accessToken.destinationType == "sc":
    _items += [_sc_netbird_namespace, _sc_access_token_secret_copy]

# elif parameters.accessToken.destinationType == "tenantVault":
#     _items += [_tenant_vault_access_token_secret_copy] # TODO: Implement tenant vault stuff
dxr = {
    **oxr
}

items = _items + [dxr]
