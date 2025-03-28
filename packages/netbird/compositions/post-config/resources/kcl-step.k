# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

## Replacement of Ansible
admin_group_name = "{}:{}".format(parameters.zitadelProjectId, parameters.groupNames.admin)
external_access_group_name = "{}:{}".format(parameters.zitadelProjectId, parameters.groupNames.externalAccess)

# Get Netbird Account ID
## HTTP Provider call to get account id

# Update Netbird Account
_account = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbAccount"
  metadata = {
    name = "{}-nb-account".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "nb-account"
    }
  }
  spec = {
    forProvider = {
      settings = {
        extra = {
          peer_approval_enabled = False
        }
        groups_propagation_enabled = True
        jwt_allow_groups = [
          admin_group_name,
          external_access_group_name
        ]
        jwt_groups_claim_name = "zitadel:grants"
        jwt_groups_enabled = True
        peer_inactivity_expiration = 0
        peer_inactivity_expiration_enabled = False
        peer_login_expiration = 86400
        peer_login_expiration_enabled = True
        regular_users_view_blocked = True
      }
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = [
      "Update",
      "LateInitialize"
    ]
  }
}

# Observe All Group
_all_group = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbGroup"
  metadata = {
    name = "{}-all-group".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "all-group"
      "crossplane.io/external-name": "All"
    }
  }
  spec = {
    forProvider = {
      name = "All"
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = ["Observe"]
  }
}

# Update Netbird DNS Settings
_dns = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbDnsSetting"
  metadata = {
    name = "{}-nb-dns-setting".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "nb-dns-setting"
    }
  }
  spec = {
    forProvider = {
      disabled_management_groups = [
        ocds["all-group"]?.Resource?.status?.atProvider?.manifest?.id or ""
      ]
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = [
      "Update",
      "LateInitialize"
    ]
  }
}

# Admin Group
_admin_group = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbGroup"
  metadata = {
    name = "{}-admin-group".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "admin-group"
      "crossplane.io/external-name": admin_group_name
    }
  }
  spec = {
    forProvider = {
      name = admin_group_name
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = ["Observe"]
  }
}

## TOOD Zitadel User Role Syncer

## Replacement of Terraform
# CC Gateway Group
_cc_gateway_group = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbGroup"
  metadata = {
    name = "{}-cc-gateway-group".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "cc-gateway-group"
    }
  }
  spec = {
    forProvider = {
      name = "{}-gateway".format(parameters.ccClusterName)
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = spec?.managementPolicies
  }
}

# CC Gateway Setup Key
_cc_gateway_setup_key = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbSetupKey"
  metadata = {
    name = "{}-cc-gw-setup-key".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "cc-gw-setup-key"
    }
  }
  spec = {
    forProvider = {
      name = "cc bastion gateway setup key"
      type = "reusable"
      auto_groups = [
        ocds["cc-gateway-group"]?.Resource?.status?.atProvider?.manifest?.id or ""
      ]
      ephemeral = False
      usage_limit = 0
      expires_in = 7776000
      allow_extra_dns_labels = False
      revoked = False
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = spec?.managementPolicies
  }
}

## Environments
_environment_groups = []
_environment_groups += [{
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbGroup"
    metadata = {
      name = "{}-{}-env-gateway-group".format(oxr.metadata.name, env)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "{}-env-gateway-group".format(env)
      }
    }
    spec = {
      forProvider = {
        name = "{}-k8s-peers".format(env)
      }
      providerConfigRef = {
        name = spec?.providerConfigsRef?.netbirdProviderConfigName
      }
      managementPolicies = spec?.managementPolicies
    }
  } for env in parameters.environments
]

## Build Server Setup Key
_setup_keys_groups = []

_setup_keys_groups += [
  ocds["admin-group"]?.Resource?.status?.atProvider?.manifest?.id or "",
  ocds["all-group"]?.Resource?.status?.atProvider?.manifest?.id or ""
]

_environment_groups_ids = []
_environment_groups_ids += [
  ocds["{}-env-gateway-group".format(env)]?.Resource?.status?.atProvider?.manifest?.id or ""
  for env in parameters.environments
]

_setup_keys_groups += _environment_groups_ids

_build_server_setup_key = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbSetupKey"
  metadata = {
    name = "{}-build-server-setup-key".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "build-server-setup-key"
    }
  }
  spec = {
    forProvider = {
      name = "build host setup key"
      type = "one-off"
      auto_groups = _setup_keys_groups
      ephemeral = False
      usage_limit = 1
      expires_in = 7776000
      allow_extra_dns_labels = False
      revoked = False
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = spec?.managementPolicies
  }
}

_build_server_setup_key_secret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-build-server-setup-key-secret".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "build-server-setup-key-secret"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.setupKey.name
                    namespace = parameters.setupKey.namespace
                }
                data = {
                  parameters?.setupKey?.buildSetupKeySecretKey = ocds["build-server-setup-key"]?.Resource?.status?.atProvider?.manifest?.key or ""
                  parameters?.setupKey?.gwSetupKeySecretKey = ocds["cc-gw-setup-key"]?.Resource?.status?.atProvider?.manifest?.key or ""
                }
                type = "Opaque"
            }
        }
        managementPolicies = spec?.managementPolicies
        providerConfigRef = {
          name = spec?.providerConfigsRef?.k8sProviderConfigName
        }
    }
}

# Add the resources to the items list
_items += [
  _all_group,
  _admin_group,
  _account,
  _dns,
  _cc_gateway_group,
  _cc_gateway_setup_key,
  _build_server_setup_key,
  _build_server_setup_key_secret,
  *_environment_groups
]

dxr = {
  **oxr
}

items = _items + [dxr]
