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
          name = spec?.providerConfigsRef?.k8sProviderConfigName
        }
    }
}

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
          network_traffic_logs_enabled = False
          network_traffic_packet_counter_enabled = False
        }
        groups_propagation_enabled = True
        jwt_allow_groups = [
          "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.admin),
          "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.externalAccess)
        ]
        jwt_groups_claim_name = "zitadel:grants"
        jwt_groups_enabled = True
        peer_inactivity_expiration = 0
        peer_inactivity_expiration_enabled = False
        peer_login_expiration = 86400
        peer_login_expiration_enabled = True
        regular_users_view_blocked = True
        routing_peer_dns_resolution_enabled = True
      }
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = [
      "Observe",
      "Update",
      "Create",
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


# Admin Group
_admin_group = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbGroup"
  metadata = {
    name = "{}-admin-group".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "admin-group"
      "crossplane.io/external-name": "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.admin)
    }
  }
  spec = {
    forProvider = {
      name = "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.admin)
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = ["Observe"]
  }
}

# ExternalAccess Group
_external_access_group = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbGroup"
  metadata = {
    name = "{}-external-access-group".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "external-access-group"
      "crossplane.io/external-name": "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.externalAccess)
    }
  }
  spec = {
    forProvider = {
      name = "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.externalAccess)
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = ["Observe"]
  }
}

## TOOD Zitadel User Role Syncer

## Build Server Setup Key
_setup_keys_groups = []

_setup_keys_groups += [
  ocds["external-access-group"]?.Resource?.status?.atProvider?.id or ""
]

_build_server_setup_key = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbSetupKey"
  metadata = {
    name = "{}-build-server-setup-key".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "build-server-setup-key"
      "crossplane.io/deletion-policy": "Delete"
      "crossplane.io/depends-on": "external-access-group"
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
    writeConnectionSecretToRef = {
      name = parameters.setupKey.name
      namespace = parameters.setupKey.namespace
    }
    managementPolicies = spec?.managementPolicies
  }
}

_netbird_admin_user_update = [{
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbUser"
    metadata = {
        name = "{}-admin-user".format(user.user_email.replace("@", "at"))
        annotations = {
            "krm.kcl.dev/composition-resource-name": "{}-admin-user".format(user.user_email.replace("@", "at"))
        }
    }
    spec = {
        forProvider = {
            name = user.user_email
            is_service_user = False
            role = "admin"
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        managementPolicies = [
          "Observe",
          "Update",
          "Create",
          "LateInitialize"
        ]
    }
} for user in ocds["nb-account"]?.Resource?.status?.atProvider?.user_list or [] if "{}:{}".format(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"]), parameters.groupNames.admin) in (user.user_groups or [])]


_nameserver = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbNameServer"
  metadata = {
    name = "{}-default-nameserver".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "default-nameserver"
    }
  }
  spec = {
    forProvider = {
      name = "default-ns"
      description = "default nameserver"
      groups = [
        ocds["all-group"]?.Resource?.status?.atProvider?.id or ""
      ]
      domains = ["clusters.local"]
      enabled = True
      primary = False
      search_domains_enabled = False
      nameservers = [
        {
          ip = "8.8.8.8"
          ns_type = "udp"
          port = 53
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
  _zitadel_project_id_secret,
]
if readyBasedOnConditions(ocds["zitadel-project-id-secret"]) and len(base64.decode(ocds["zitadel-project-id-secret"]?.Resource?.status?.atProvider?.manifest?.data?[parameters?.zitadelProjectIdSecret?.key or "unknown"])) == 18:
    _items += [
      _account,
    ]

if readyBasedOnConditions(ocds["nb-account"]):
    _items += [
      _all_group,
      _admin_group,
      _external_access_group,
      _build_server_setup_key,
      _nameserver,
    ] + _netbird_admin_user_update

dxr = {
  **oxr
}

items = _items + [dxr]
