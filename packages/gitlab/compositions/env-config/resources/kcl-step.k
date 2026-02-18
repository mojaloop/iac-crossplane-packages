import datetime
import regex
import base64
import crypto

# Read the XR
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters


_items = []

_environments = (parameters?.environments or "").split(",")

_environmentProjects = [{
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XProject"
    metadata = {
        name = "project-{}".format(projectName)
        annotations = {
                "krm.kcl.dev/composition-resource-name" = "project-{}".format(projectName)
        }
    }
    spec = {
        parameters = {
            project = {
                name = projectName
                onlyAllowMergeIfPipelineSucceeds = False
                onlyAllowMergeIfAllDiscussionsAreResolved = False
                requestAccessEnabled = True
                pagesAccessLevel = "private"
                groupIdSelector = {
                  matchLabels = {
                    "gitlab.mojaloop.com/group-name" = parameters?.groupName
                  }
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            gitlabProvider = spec?.providerConfigsRef?.gitlabProvider
        }
    }
} for projectName in _environments or []
]

_projectIds = {
  projectName: ocds["project-{}".format(projectName)]?.Resource?.status?.atProvider?.id or ""
  for projectName in _environments or []
}


_projectAccessTokens = [{
    apiVersion = "projects.gitlab.crossplane.io/v1alpha1"
    kind = "AccessToken"
    metadata = {
        name = "accesstoken-{}".format(projectName)
        annotations = {
                "krm.kcl.dev/composition-resource-name" = "accesstoken-{}".format(projectName)
        }

    }
    spec = {
        forProvider = {
            projectIdSelector = {
                matchLabels = {
                   "gitlab.mojaloop.com/project-name" = projectName
                }
            }
            name = "accesstoken-{}".format(projectName)
            accessLevel = 40
            scopes = ["api", "read_api", "read_registry", "read_repository", "write_repository"]
            expiresAt = parameters?.expiresAt
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
        writeConnectionSecretToRef = {
            name = "{}-project-access-token".format(projectName)
            namespace = parameters?.namespace
        }
    }

} for projectName in _environments or []
]

_groupVariables = [ {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Variable"
    metadata = {
        name = "var-{}".format(variable.key.replace("_", "-").lower())
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "var-{}".format(variable.key.replace("_", "-").lower())
        }
    }
    spec = {
        forProvider = {
            groupIdSelector = {
                matchLabels = {
                "gitlab.mojaloop.com/group-name" = parameters?.groupName
                }
            }
            key = variable.key
            value = variable.value
            protected = variable.protected
            masked = variable.masked
            environmentScope = variable.environmentScope
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
} for variable in parameters?.groupVariables or []
]

_repoSecrets = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-repo-creds".format(projectName)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "repo-creds-{}".format(projectName)
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = "{}-repo-creds".format(projectName)
                    namespace = parameters?.argocdNamespace
                }
                labels = {
                    "argocd.argoproj.io/secret-type" = "repo-creds"
                }
                data = {
                    "password"  = ocds["{}-project-access-token".format(projectName)]?.Resource?.status?.atProvider?.manifest?.data?["token"]
                    "url"       = base64.encode(ocds["project-{}".format(projectName)]?.Resource?.status?.atProvider?.httpUrlToRepo)
                    "type"      = base64.encode("git")
                    "project"   = base64.encode("default")
                    "username"  = base64.encode("token")
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.kubernetesProvider
        }
    }
} for projectName in _environments or []
]

_envVaulttokens = {
  projectName: base64.decode(ocds["env-token-secret-{}".format(projectName)]?.Resource?.status?.atProvider?.manifest?.data?["attribute.client_token"]) or ""
  for projectName in _environments or []
}

_vaultTokenUpdateJobs = [{
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-envtoken-renew-job-{}".format(
            projectName,
            crypto.sha256(_envVaulttokens[projectName])[:10]
        )
        annotations = {
            "krm.kcl.dev/composition-resource-name": "{}-envtoken-renew-job-{}".format(
                projectName,
                crypto.sha256(_envVaulttokens[projectName])[:10]
            )
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "batch/v1"
                kind = "Job"
                metadata = {
                    name = "{}-envtoken-renew-job-{}".format(
                        projectName,
                        crypto.sha256(_envVaulttokens[projectName])[:10]
                    )
                    namespace = parameters.namespace
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
                                env = [
                                    {
                                        name = "VAULT_TOKEN"
                                        valueFrom = {
                                            secretKeyRef = {
                                                name = "env-token-secret-{}".format(projectName)
                                                key = "attribute.client_token"
                                            }
                                        }
                                    },
                                    {
                                        name = "PRIVATE_TOKEN"
                                        valueFrom = {
                                            secretKeyRef = {
                                                name = "{}-project-access-token".format(projectName)
                                                key = "token"
                                            }
                                        }
                                    }
                                ]
                                args = ["""
                                    set -e

                                    apk add --no-cache curl jq
                                    GITLAB_URL="https://{gitlabFqdn}/api/v4/projects/{projectId}/repository/files/%2Evault_token_trigger"

                                    TOKEN="$VAULT_TOKEN"

                                    if [ -z "$TOKEN" ] || [ -z "$PRIVATE_TOKEN" ]; then
                                        echo "Error: Tokens not found in environment variables"
                                        exit 1
                                    fi

                                    ENCODED_TOKEN=$(echo -n "$TOKEN" | base64 | tr -d '\n')

                                    # Fetch file (GET) - Capture status code
                                    http_code=$(curl -s -o resp.json -w "%{{http_code}}" -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" "$GITLAB_URL?ref=main")
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
                                            update_code=$(curl -s -o /dev/null -w "%{{http_code}}" -X PUT "$GITLAB_URL" \
                                            -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
                                            -H "Content-Type: application/json" \
                                            -d "{{
                                                \\"branch\\": \\"main\\",
                                                \\"commit_message\\": \\"tf_trigger: vault_token_update\\",
                                                \\"content\\": \\"$ENCODED_TOKEN\\",
                                                \\"encoding\\": \\"base64\\",
                                                \\"author_name\\": \\"Crossplane\\"
                                            }}")

                                            if [ "$update_code" -lt 200 ] || [ "$update_code" -ge 300 ]; then
                                                echo "Error: Failed to update file. HTTP Status: $update_code"
                                                exit 1
                                            fi
                                            echo "Successfully updated file."
                                        fi
                                    elif [ "$http_code" -eq 404 ]; then
                                        echo "File not found, creating new file..."
                                        create_code=$(curl -s -o /dev/null -w "%{{http_code}}" -X POST "$GITLAB_URL" \
                                            -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
                                            -H "Content-Type: application/json" \
                                            -d "{{
                                            \\"branch\\": \\"main\\",
                                            \\"commit_message\\": \\"tf_trigger: vault_token_create\\",
                                            \\"content\\": \\"$ENCODED_TOKEN\\",
                                            \\"encoding\\": \\"base64\\",
                                            \\"author_name\\": \\"Crossplane\\"
                                            }}")

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
                                    """.format(
                                        gitlabFqdn=parameters?.gitlabFqdn,
                                        projectId=_projectIds[projectName]
                                    )]
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
    }
} for projectName in _environments or []
]


_items += _environmentProjects + _projectAccessTokens + _groupVariables + _repoSecrets + _vaultTokenUpdateJobs

dxr = {
    **oxr
}

items = _items + [dxr]
