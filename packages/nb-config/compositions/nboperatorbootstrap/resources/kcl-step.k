import base64
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

_external_access_group = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbGroup"
    metadata = {
        name = "{}-external-access-group".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "external-access-group"
            "crossplane.io/external-name":           "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.externalAccess)
        }
    }
    spec = {
        forProvider = {
            name =           "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.externalAccess)
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        managementPolicies = ["Observe"]
    }
}
# Kubernetes Group
_network_resource_group = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbGroup"
    metadata = {
        name = "{}-network-resource-group".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "network-resource-group"
        }
    }
    spec = {
        forProvider = {
            name = parameters.groupNames.networkResourceGroup
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
if parameters.accessToken.destinationType == "local" or parameters.accessToken.destinationType == "tenantVault":
    _access_token_secret_name = parameters.accessToken.localSecretName
    _access_token_secret_namespace = parameters.accessToken.localSecretNamespace or oxr.metadata.namespace or "crossplane-system"
else:
    _access_token_secret_name = "{}-access-token".format(oxr.metadata.name)
    _access_token_secret_namespace = oxr.metadata.namespace or "crossplane-system"
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
            user_id: ocds["service-user"]?.Resource?.status?.atProvider?.id or ""
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

if parameters.accessToken.destinationType == "tenantVault":
  _push_secret_access_token = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
      name = "{}-push-secret-access-token".format(oxr.metadata.name)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "push-secret-access-token"
      }
    }
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "external-secrets.io/v1alpha1"
          kind = "PushSecret"
          metadata = {
            name = ocds["access-token"]?.Resource?.spec?.writeConnectionSecretToRef?.name or ""
            namespace = ocds["access-token"]?.Resource?.spec?.writeConnectionSecretToRef?.namespace or ""
          }
          spec = {
            updatePolicy = parameters.pushSecret.esoUpdatePolicy
            deletionPolicy = parameters.pushSecret.esoDeletePolicy
            refreshInterval = parameters.pushSecret.esoRefreshInterval
            secretStoreRefs = [
              {
                name = parameters.pushSecret.vaultSecretStore
                kind = parameters.pushSecret.vaultSecretStoreKind
              }
            ]
            selector = {
              secret = {
                name = ocds["access-token"]?.Resource?.spec?.writeConnectionSecretToRef?.name or ""
              }
            }
            data = [
              {
                match = {
                  secretKey = "NB_API_KEY"
                  remoteRef = {
                    remoteKey = parameters.accessToken.vaultSecretPath
                    property = "value"
                  }
                }
              }
            ]
          }
        }
      }
      managementPolicies = spec.managementPolicies
      providerConfigRef = {
        name = spec.providerConfigsRef.ccK8sProviderName
      }
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
                        labels = {
                            "hostport.rmb938.com": "true"
                        }
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
                    namespace = parameters.operatorNamespace
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
    _sc_nb_operator_kyverno_policy = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-sc-nb-operator-kyverno-policy-install".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "sc-nb-operator-policy-kyverno-install"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "kyverno.io/v1"
                    kind = "ClusterPolicy"
                    metadata = {
                        name = "nbrouter-add-security-context"
                        annotations = {
                            "policies.kyverno.io/title": "Add security context to nbrouter deployment"
                            "policies.kyverno.io/description": "This policy updates pod security context of nbrouter deployment"
                        }
                    }
                    spec = {
                        rules = [
                            {
                                name = "nbrouter-add-security-context"
                                match = {
                                    "any" = [
                                        {
                                            resources = {
                                                kinds = ["Pod"]
                                                namespaces = [parameters.operatorNamespace]
                                                selector = {
                                                    matchLabels = {
                                                        "app.kubernetes.io/name": "netbird-router"
                                                    }
                                                }
                                            }
                                        }
                                    ]
                                }
                                context = [
                                    {
                                        name = "hostportclaim"
                                        apiCall = {
                                            urlPath = "/apis/hostport.rmb938.com/v1alpha1/namespaces/{{ request.namespace }}/hostportclaims/netbird-{{ request.object.metadata.ownerReferences[0].name | split(@, '-') | [0:-1] | join('-', @) }}"
                                            jmesPath = "spec.hostPortName"
                                        }
                                    }
                                    {
                                        name = "hostport"
                                        apiCall = {
                                            urlPath = "/apis/hostport.rmb938.com/v1alpha1/hostports/{{ hostportclaim }}"
                                            jmesPath = "status.port"
                                        }
                                    }
                                ]
                                mutate = {
                                    patchesJson6902 = """
        - op: add
        path: /metadata/annotations/claim.hostport.rmb938.com~1router
        value: "netbird-{{ request.object.metadata.ownerReferences[0].name | split(@, '-') | [0:-1] | join('-', @) }}"
        # Inject the ACTUAL port into the spec immediately
        - op: add
        path: "/spec/containers/0/ports"
        value: 
        - name: router
            containerPort: 51820
            hostPort: {{ hostport }}
            protocol: UDP
        - op: add
        path: "/spec/containers/0/env/-"
        value: {"name": "NB_EXTERNAL_IP", "valueFrom": {"fieldRef": {"fieldPath": "status.hostIP"}}}
        # Static injection of the port into the ENV (more reliable than fieldRef for annotations)
        - op: add
        path: "/spec/containers/0/env/-"
        value: {"name": "NB_LISTEN_PORT", "value": "{{ hostport }}"}
        - op: add
        path: "/spec/securityContext"
        value: {"sysctls": [{"name": "net.ipv4.ip_forward", "value": "1"}]}
        """
                                }
                                preconditions = {
                                    "all" = [
                                        {
                                            key = "{{ request.operation }}"
                                            operator = "In"
                                            value = ["CREATE", "UPDATE"]
                                        }
                                    ]
                                }
                                skipBackgroundRequests = True
                            }
                        ]
                        validationFailureAction = "Audit"
                    }
                }
            }
            managementPolicies = spec?.managementPolicies
            providerConfigRef = {
                name = spec?.providerConfigsRef?.scK8sProviderName
            }
        }
    }

    _sc_nb_op_secret_update_kyverno_policy = {
        apiVersion = "kubernetes.crossplane.io/v1alpha2"
        kind = "Object"
        metadata = {
            name = "{}-sc-nb-op-secret-update-kyverno-policy-install".format(oxr.metadata.name)
            annotations = {
                "krm.kcl.dev/composition-resource-name": "sc-nb-op-secret-update-kyverno-policy-install"
            }
        }
        spec = {
            forProvider = {
                manifest = {
                    apiVersion = "kyverno.io/v1"
                    kind = "ClusterPolicy"
                    metadata = {
                        name = "restart-netbird-operator"
                        namespace = parameters.operatorNamespace
                        annotations = {
                            "policies.kyverno.io/title": "Restart netbird operator pod on secret update"
                            "policies.kyverno.io/description": "This policy requires the restart of netbird operator pod when the secret is updated"
                        }
                    }
                    spec = {
                        rules = [
                            {
                                name = "add-annotation-on-secret-update"
                                match = {
                                    "any" = [
                                        {
                                            resources = {
                                                kinds = [
                                                    "Secret"
                                                ]
                                                names = [
                                                    "nb-operator-api-key"
                                                ]
                                                namespaces = [
                                                    parameters.operatorNamespace
                                                ]
                                            }
                                        }
                                    ]
                                }
                                mutate = {
                                    patchStrategicMerge = {
                                        spec = {
                                            template = {
                                                metadata = {
                                                    annotations = {
                                                        "kyverno.platform.mojaloop.com/triggerrestart": "{{request.object.metadata.resourceVersion}}"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    targets = [
                                        {
                                            apiVersion = "apps/v1"
                                            kind = "Deployment"
                                            namespace = parameters.operatorNamespace
                                            selector = {
                                                matchLabels = {
                                                    "app.kubernetes.io/name": "kubernetes-operator"
                                                }
                                            }
                                        }
                                    ]
                                }
                                preconditions = {
                                    "any" = [
                                        {
                                            key = "{{request.operation}}"
                                            operator = "In"
                                            value = ["UPDATE"]
                                        }
                                    ]
                                }
                                skipBackgroundRequests = True
                            }
                        ]
                        validationFailureAction = "Audit"
                    }
                }
            }
            managementPolicies = spec?.managementPolicies
            providerConfigRef = {
                name = spec?.providerConfigsRef?.scK8sProviderName
            }
        }
    }
# elif parameters.accessToken.destinationType == "tenantVault":
#     # TODO: Implement tenant vault stuff
_internal_network_policy = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbPolicy"
    metadata = {
        name = "{}-internal-network-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "internal-network-policy"
        }
    }
    spec = {
        forProvider = {
            name = "{}-internal-network-policy".format(oxr.metadata.name)
            enabled = True
            description = "Policy for connecting to internal network for {}".format(oxr.metadata.name)
            rules = [
                {
                    action = "accept"
                    bidirectional = False
                    description = "internal network accept"
                    name = "internal-network-accept-rule"
                    enabled = True
                    destinations = [
                        {
                            id = ocds["network-resource-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    sources = [
                        {
                            id = ocds["external-access-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    protocol = "all"
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
]

if readyBasedOnConditions(ocds["zitadel-project-id-secret"]):
    _items += [
        _external_access_group
        _network_resource_group
        _service_user
        _access_token
    ]
    if parameters.accessToken.destinationType == "sc":
        _items += [_sc_netbird_namespace, _sc_access_token_secret_copy, _sc_nb_operator_kyverno_policy, _sc_nb_op_secret_update_kyverno_policy]
    if parameters.accessToken.destinationType == "tenantVault":
        _items += [_push_secret_access_token]


if readyBasedOnConditions(ocds["external-access-group"]) and readyBasedOnConditions(ocds["network-resource-group"]):
    _items += [
        _internal_network_policy
    ]

# elif parameters.accessToken.destinationType == "tenantVault":
#     _items += [_tenant_vault_access_token_secret_copy] # TODO: Implement tenant vault stuff
dxr = {
    **oxr
}

items = _items + [dxr]
