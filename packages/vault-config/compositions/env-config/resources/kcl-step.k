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

_environments = (parameters?.environments or "").split(",")


## Adding resources
_mountObject = {
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Mount"
    metadata = {
        name = "transit-mount"
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "transit-mount"
        }
    }
    spec = {
        deletionPolicy = "Delete"
        forProvider = {
            path = "transit"
            type = "transit"
            description = "Transit secrets engine for unsealing and encryption"

        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
}

_transitSecretBackendKeys = [{
    apiVersion = "transit.vault.upbound.io/v1alpha1"
    kind = "SecretBackendKey"
    metadata = {
        name = "unseal-key-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "unseal-key-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            backendSelector = {
                matchControllerRef = True
            }
            name = "unseal-key-{}".format(env)
            deletionAllowed = True
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
} for env in _environments or []]


_unsealkeys = {
  env : ocds["unseal-key-{}".format(env)]?.Resource?.status?.atProvider?.name or ""
  for env in _environments or []
}

_transitPolicies = [{
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Policy"
    metadata = {
        name = "env-transit-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "env-transit-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            name = "env-transit-{}".format(env)
            policy = """
                path "{}/data/{}/*"{{
                    capabilities = ["read", "list","create","update","delete"]
                }}
                path "{}/metadata/{}/*" {{
                    capabilities = ["read", "list","create","update","delete"]
                }}
                path "{}/data/tenancy/*" {{
                    capabilities = ["read", "list"]
                }}
                path "{}/data/gitlab/*" {{
                capabilities = ["read", "list"]
                }}
                path "auth/token/*" {{
                    capabilities = ["read","create","update"]
                }}
                path "transit/encrypt/{}" {{
                capabilities = [ "update" ]
                }}

                path "transit/decrypt/{}" {{
                capabilities = [ "update" ]
                }}

                path "transit/encrypt/{}-migrated" {{
                capabilities = [ "update" ]
                }}

                path "transit/decrypt/{}-migrated" {{
                capabilities = [ "update" ]
                }}
                """.format(parameters.kvPath, env, parameters.kvPath, env, parameters.kvPath, parameters.kvPath, _unsealkeys[env], _unsealkeys[env], _unsealkeys[env], _unsealkeys[env])
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
} for env in _environments or []]


_envTokens = [{
    apiVersion = "vault.vault.upbound.io/v1alpha1"
    kind = "Token"
    metadata = {
        name = "env-token-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "env-token-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            policies = ["env-transit-{}".format(env)]
            noParent = True
            ttl = parameters?.envTokenTTL
            renewable= True

        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
        writeConnectionSecretToRef = {
            name = "env-token-secret-{}".format(env)
            namespace = env
        }
    }

} for env in _environments or []
]

_k8sObserveSecret = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "env-token-k8secret-observe-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-token-k8secret-observe-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "env-token-secret-{}".format(env)
                    namespace = env
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}for env in _environments or []
]

_jsonPayload = {
    env: {
        "value": base64.decode(ocds["env-token-k8secret-observe-{}".format(env)]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_token"] if ocds["env-token-k8secret-observe-{}".format(env)]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_token"] else "")
    }
    for env in _environments or []
}

_payloadHash = {
    env: crypto.sha256(json.encode(_jsonPayload[env]))[:8] # First 8 chars of hash
    for env in _environments or []
}


_k8sSecrets = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "env-token-k8secret-{}-{}".format(env, _payloadHash[env])
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-token-k8secret-{}-{}".format(env, _payloadHash[env])
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "env-token-k8secret-{}-{}".format(env, _payloadHash[env])
                    namespace = env
                }
                data = {
                    "credentials" = base64.encode(json.encode(_jsonPayload[env]))
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProvider
        }
    }
}for env in _environments or []
]


_envTokenSecrets = [{
    apiVersion = "generic.vault.upbound.io/v1alpha1"
    kind = "Secret"
    metadata = {
        name = "env-token-vault-secret-{}-{}".format(env, _payloadHash[env])
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-token-vault-secret-{}-{}".format(env, _payloadHash[env])
        }
    }
    spec = {
        forProvider = {
            dataJsonSecretRef = {
                key = "credentials"
                name = "env-token-k8secret-{}-{}".format(env, _payloadHash[env])
                namespace = env
            }
            deleteAllVersions = True
            path = "{}/{}/env_token".format(parameters.kvPath, env)
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.vaultProvider
        }
    }
}for env in _environments or []]


_unsealVariables = [ {
    apiVersion = "projects.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata = {
        name = "project-var-{}".format(env)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "project-var-{}".format(env)
        }
    }
    spec = {
        forProvider = {
            projectIdSelector = {
                matchLabels = {
                   "gitlab.mojaloop.com/project-name" = env
                }
            }
            key = "TRANSIT_VAULT_UNSEAL_KEY_NAME"
            value = _unsealkeys[env]
            protected = False
            masked = False
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
} for env in _environments or []
]

_scriptContent = """set -e

apk add --no-cache curl jq
GITLAB_URL="https://$GITLAB_FQDN/api/v4/projects/$PROJECT_ID/repository/files/%2Evault_token_trigger"

TOKEN="$VAULT_TOKEN"

if [ -z "$TOKEN" ] || [ -z "$PRIVATE_TOKEN" ]; then
    echo "Error: Tokens not found in environment variables"
    exit 1
fi

ENCODED_TOKEN=$(echo -n "$TOKEN" | base64 | tr -d '\n')
DOUBLE_ENCODED_TOKEN=$(echo -n "$ENCODED_TOKEN" | base64 | tr -d '\n')

# Fetch file (GET) - Capture status code
http_code=$(curl -s -o resp.json -w "%{http_code}" -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" "$GITLAB_URL?ref=main")
curl_exit=$?

if [ $curl_exit -ne 0 ]; then
    echo "Error: Curl failed to fetch file (exit code $curl_exit)"
    exit 1
fi

if [ "$http_code" -eq 200 ]; then
    current=$(jq -r .content resp.json)
    # Decode current content to compare with raw token
    current_decoded=$(echo "$current" | base64 -d)

    if [ "$current_decoded" = "$TOKEN" ]; then
        echo "Token already up to date. Nothing to do."
        exit 0
    else
        echo "Updating file with new token..."
        update_code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$GITLAB_URL" \
        -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "branch": "main",
            "commit_message": "tf_trigger: vault_token_update",
            "content": "'"$DOUBLE_ENCODED_TOKEN"'",
            "encoding": "base64",
            "author_name": "Crossplane"
        }')

        if [ "$update_code" -lt 200 ] || [ "$update_code" -ge 300 ]; then
            echo "Error: Failed to update file. HTTP Status: $update_code"
            exit 1
        fi
        echo "Successfully updated file."
    fi
elif [ "$http_code" -eq 404 ]; then
    echo "File not found, creating new file..."
    create_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GITLAB_URL" \
        -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
        "branch": "main",
        "commit_message": "tf_trigger: vault_token_create",
        "content": "'"$DOUBLE_ENCODED_TOKEN"'",
        "encoding": "base64",
        "author_name": "Crossplane"
        }')

    if [ "$create_code" -lt 200 ] || [ "$create_code" -ge 300 ]; then
        echo "Error: Failed to create file. HTTP Status: $create_code"
        exit 1
    fi
    echo "Successfully created file."
else
    echo "Unexpected status code fetching file: $http_code"
    cat resp.json || true
    exit 1
fi
"""

_vaultTokenUpdateJobs = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-envtokenrenew-{}".format(env, _payloadHash[env])
        annotations = {
            "krm.kcl.dev/composition-resource-name": "{}-envtokenrenew-{}".format(env, _payloadHash[env])
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "batch/v1"
                kind = "Job"
                metadata = {
                    name = "{}-envtokenrenew-{}".format(env, _payloadHash[env])
                    namespace = env
                }
                spec = {
                    backoffLimit = 1
                    template = {
                        spec = {
                            restartPolicy = "Never"
                            containers = [{
                                name = "vault-token-renewer"
                                image = "alpine:3.20"
                                command = ["/bin/sh", "-c"]
                                "env" = [
                                    {
                                        name = "VAULT_TOKEN"
                                        valueFrom = {
                                            secretKeyRef = {
                                                name = "env-token-secret-{}".format(env)
                                                key = "attribute.client_token"
                                            }
                                        }
                                    },
                                    {
                                        name = "PRIVATE_TOKEN"
                                        valueFrom = {
                                            secretKeyRef = {
                                                name = "{}-project-access-token".format(env)
                                                key = "token"
                                            }
                                        }
                                    },
                                    {
                                        name = "PROJECT_ID"
                                        valueFrom = {
                                            secretKeyRef = {
                                                name = "project-id-secret-{}".format(env)
                                                key = "project_id"
                                            }
                                        }
                                    },
                                    {
                                        name = "GITLAB_FQDN"
                                        valueFrom = {
                                            secretKeyRef = {
                                                name = "project-id-secret-{}".format(env)
                                                key = "gitlab_fqdn"
                                            }
                                        }

                                    }
                                ]
                                args = [_scriptContent]
                                    }]
                        }
                    }
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.kubernetesProvider
        }
        readiness = {
            policy = "DeriveFromCelQuery"
            celQuery = "has(object.status.conditions) && object.status.conditions.exists(c, c.type == 'Complete' && c.status == 'True')"
        }
    }
} for env in _environments or []
]

_items += [_mountObject] + _transitSecretBackendKeys + _transitPolicies + _envTokens + _k8sObserveSecret + _k8sSecrets + _envTokenSecrets + _unsealVariables + _vaultTokenUpdateJobs

dxr = {
    **oxr
}

items = _items + [dxr]
