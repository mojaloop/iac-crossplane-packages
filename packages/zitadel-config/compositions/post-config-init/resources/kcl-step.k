import json
import base64
import crypto

# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
params = spec.parameters
metadata = oxr.metadata
namespace = params.namespace or "zitadel"

# 1. Observe Zitadel admin sa secret
_observe_zitadel_admin_sa = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-admin-sa-observe".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "zitadel-admin-sa-observe"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {
                name = params.zitadelAdminSecret.name
                namespace = namespace
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

# 2. Extract Data from Observed Secret
_raw_data = ocds["zitadel-admin-sa-observe"]?.Resource?.status?.atProvider?.manifest?.data?[params.zitadelAdminSecret.key] or ""
_sa_json = json.decode(base64.decode(_raw_data)) if _raw_data else {}

user_id = _sa_json.userId or ""
key_id = _sa_json.keyId or ""
private_key = (_sa_json.key or "").replace("\\n", "\n")

# 3. Define the Script with K8s Secret Creation Logic
_script_content = """
set -e
echo "Waiting for {DOMAIN}..."
until curl -skf "https://{DOMAIN}/debug/healthz"; do sleep 5; done

cat <<EOF > /tmp/privkey.pem
{PRIV_KEY}
EOF

b64url() {{ openssl base64 -e -A | tr -d '=' | tr '+/' '-_'; }}

echo "Starting retry loop for Org ID..."
for i in $(seq 1 20); do
  # Offset IAT by 5 mins to handle clock skew
  IAT=$(($(date +%s) - 300))
  EXP=$((IAT + 3600))

  HEADER=$(echo -n '{{"alg":"RS256","typ":"JWT","kid":"{KID}"}}' | b64url)
  PAYLOAD=$(echo -n '{{"iss":"{UID}","sub":"{UID}","aud":"https://{DOMAIN}","iat":'$IAT',"exp":'$EXP'}}' | b64url)
  SIG=$(echo -n "$HEADER.$PAYLOAD" | openssl dgst -sha256 -sign /tmp/privkey.pem -binary | b64url)

  RESPONSE=$(curl -s -X POST "https://{DOMAIN}/oauth/v2/token" \\
    -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \\
    -d "scope=openid urn:zitadel:iam:org:project:id:zitadel:aud" \\
    -d "assertion=$HEADER.$PAYLOAD.$SIG")

  TOKEN=$(echo "$RESPONSE" | sed -n 's/.*"access_token":"\\([^"]*\\)".*/\\1/p')

  if [ -n "$TOKEN" ]; then
    ORG_ID_RAW=$(curl -s -H "Authorization: Bearer $TOKEN" "https://{DOMAIN}/admin/v1/orgs/default")
    ORG_ID=$(echo "$ORG_ID_RAW" | sed -n 's/.*"id":"\\([^"]*\\)".*/\\1/p')

    if [ -n "$ORG_ID" ]; then
      echo "FOUND_ORG_ID=$ORG_ID"

      K8S_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
      ORG_B64=$(echo -n "$ORG_ID" | base64)

      echo "Upserting Secret {OUT_SECRET}..."
      cat <<EOF > /tmp/secret-patch.yaml
apiVersion: v1
kind: Secret
metadata:
  name: {OUT_SECRET}
  namespace: $NAMESPACE
type: Opaque
data:
  {OUT_KEY}: $ORG_B64
EOF
      HTTP_STATUS=$(curl -s -o /tmp/k8s_resp.json -w "%{{http_code}}" -X PATCH \\
        "https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/secrets/{OUT_SECRET}?fieldManager=zitadel-init&force=true" \\
        --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \\
        -H "Authorization: Bearer $K8S_TOKEN" \\
        -H "Content-Type: application/apply-patch+yaml" \\
        --data-binary @/tmp/secret-patch.yaml)

      if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 201 ]; then
        echo "Secret {OUT_SECRET} processed successfully (HTTP $HTTP_STATUS)."
        exit 0
      else
        echo "CRITICAL ERROR: Failed to upsert secret. HTTP Status: $HTTP_STATUS"
        cat /tmp/k8s_resp.json
        exit 1
      fi
    fi
  fi
  echo "Attempt $i failed, retrying..."
  sleep 10
done
exit 1
""".format(
    DOMAIN = params.domain,
    UID = user_id,
    KID = key_id,
    PRIV_KEY = private_key,
    OUT_SECRET = params.zitadelInitOutputSecret.name,
    OUT_KEY = params.zitadelInitOutputSecret.key
)

_script_hash = crypto.sha256(_script_content)[:8]
_cm_name = "{}-getter-script-{}".format(metadata.name, _script_hash)
_job_name = "{}-getter-{}".format(metadata.name, _script_hash)

# 4. Storage for the Script (Secret)
_script_cm = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = _cm_name
        annotations = {"krm.kcl.dev/composition-resource-name": "script-cm"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {
                name = _cm_name
                namespace = namespace
            }
            stringData = {"fetch-org.sh" = _script_content}
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

_sa_name = "{}-getter-sa".format(metadata.name)
_role_name = "{}-role".format(metadata.name)
_rb_name =  "{}-rb".format(metadata.name)

# 1. ServiceAccount for the Job
_job_sa = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-sa".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "job-sa"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "ServiceAccount"
            metadata = {
                name = _sa_name
                namespace = namespace
            }
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

# 2. Role to allow Secret creation
_job_role = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-role".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "job-role"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "rbac.authorization.k8s.io/v1"
            kind = "Role"
            metadata = {
                name = _role_name
                namespace = namespace
            }
            rules = [{
                apiGroups = [""]
                resources = ["secrets"]
                verbs = ["create", "get", "patch", "update"]
            }]
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

# 3. RoleBinding to link SA and Role
_job_rb = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-rb".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "job-rb"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "rbac.authorization.k8s.io/v1"
            kind = "RoleBinding"
            metadata = {
                name = _rb_name
                namespace = namespace
            }
            roleRef = {
                apiGroup = "rbac.authorization.k8s.io"
                kind = "Role"
                name = _role_name
            }
            subjects = [{
                kind = "ServiceAccount"
                name = _sa_name
                namespace = namespace
            }]
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}


# 5. Job Definition
_zitadelPostConfigInit = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = _job_name
        annotations = {"krm.kcl.dev/composition-resource-name": "post-config-job"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "batch/v1"
            kind = "Job"
            metadata = {
                name = _job_name
                namespace = namespace
            }
            spec.template.spec = {
                backoffLimit = "5"
                ttlSecondsAfterFinished = "300"
                serviceAccountName = _sa_name
                containers = [{
                    name = "zitadel-helper"
                    image = "alpine:latest"
                    command = ["/bin/sh", "-c", "apk add --no-cache curl openssl && sh /scripts/fetch-org.sh"]
                    volumeMounts = [{
                        name = "script-vol"
                        mountPath = "/scripts"
                    }]
                }]
                restartPolicy = "Never"
                volumes = [{
                    name = "script-vol"
                    secret = {
                        secretName = _cm_name
                        defaultMode = 0o755
                    }
                }]
            }
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

# secret to observe org id

_observe_zitadel_org_secret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-org-secret-observe".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "zitadel-org-secret-observe"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {
                name = params.zitadelInitOutputSecret.name
                namespace = namespace
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

_orgId = base64.decode(ocds["zitadel-org-secret-observe"]?.Resource?.status?.atProvider?.manifest?.data?[params.zitadelInitOutputSecret.key]) or ""

# secret to store initial password

_password_raw = "#Password1!"

_human_admin_password_secret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-human-admin-initial-pass".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "human-admin-initial-pass"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {
                name = "{}-human-admin-initial-pass".format(metadata.name)
                namespace = namespace
            }
            data = {
                password = base64.encode(_password_raw)
            }
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

_zitadelAdminHumanUser = {
    apiVersion = "human.zitadel.crossplane.io/v1alpha1"
    kind = "User"
    metadata = {
        name = "{}-adm-human-user".format(metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-adm-human-user"
        }
    }
    spec = {
        forProvider = {
            orgId = _orgId
            userName = "rootauto@zitadel.{}".format(params.domain)
            firstName = "root"
            lastName = "admin"
            nickName = "admin"
            displayName = "Zitadel Admin"
            preferredLanguage = "en"
            gender = "GENDER_MALE"
            email = "admin@{}.format(params.domain)"
            isEmailVerified = True
            # Human users require a reference to a secret for the initial password
            initialPasswordSecretRef = {
                name = "{}-human-admin-initial-pass".format(oxr.metadata.name)
                key = "password"
                namespace = namespace
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

_adminUserId = ocds["zitadel-adm-human-user"]?.Resource?.status?.atProvider?.id or ""

_adminUserIdOutputSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-human-admin-id-secret".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "human-admin-id-secret"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "Secret"
            metadata = {
                name = params.zitadelPostConfigOutputSecret.name
                namespace = namespace
            }
            data = {
                params.zitadelPostConfigOutputSecret.key = base64.encode(_adminUserId)
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

_zitadelInstanceMember = {
    apiVersion = "instance.zitadel.crossplane.io/v1alpha1"
    kind = "Member"
    metadata = {
        name = "{}-instance-admin-member".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "zitadel-instance-admin-member"
        }
    }
    spec = {
        forProvider = {
            userId = _adminUserId
            roles = ["IAM_OWNER"]
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

_zitadelOrgMember = {
    apiVersion = "org.zitadel.crossplane.io/v1alpha1"
    kind = "Member"
    metadata = {
        name = "{}-admin-user-org-memeber".format(metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "admin-user-org-memeber"
        }
    }
    spec = {
        forProvider = {
            orgId = _orgId
            userId = _adminUserId
            roles = ["ORG_OWNER"]
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.zitadelProviderName
        }
    }
}

_flatRoleScript = """
function flatRoles(ctx, api) {{
    if (ctx.v1.user.grants == undefined || ctx.v1.user.grants.count == 0) {{
        return;
    }}

    let grants = [];
    ctx.v1.user.grants.grants.forEach(claim => {{
        claim.roles.forEach(role => {{
            grants.push(claim.projectId + ':' + role)
        }})
    }})
    api.v1.claims.setClaim('{GROUP_CLAIM_REFIX}', grants)
}}""".format(
    GROUP_CLAIM_REFIX = params.oidcProviderGroupClaimPrefix
)

_zitadelActionFlatRoles = {
    apiVersion = "zitadel.zitadel.crossplane.io/v1alpha1"
    kind = "Action"
    metadata = {
        name = "{}-flat-roles-action".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "flat-roles-action"
        }
    }
    spec = {
        forProvider = {
            orgId = _orgId
            name = "flatRoles"
            allowedToFail = True
            timeout = "10s"
            # Using a multi-line string for the JS script
            script = _flatRoleScript

        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

_actionId = ocds["flat-roles-action"]?.Resource?.status?.atProvider?.id or ""

_zitadelTriggerPreUserInfo = {
    apiVersion = "trigger.zitadel.crossplane.io/v1alpha1"
    kind = "Actions"
    metadata = {
        name = "{}-pre-userinfo-trigger".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "pre-userinfo-trigger"
        }
    }
    spec = {
        forProvider = {
            orgId = _orgId
            flowType = "FLOW_TYPE_CUSTOMISE_TOKEN"
            triggerType = "TRIGGER_TYPE_PRE_USERINFO_CREATION"
            actionIds = [_actionId]
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

_zitadelTriggerPreAccessToken = {
    apiVersion = "trigger.zitadel.crossplane.io/v1alpha1"
    kind = "Actions"
    metadata = {
        name = "{}-pre-access-token-trigger".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name" = "pre-access-token-trigger"
        }
    }
    spec = {
        forProvider = {
            orgId = _orgId
            flowType = "FLOW_TYPE_CUSTOMISE_TOKEN"
            triggerType = "TRIGGER_TYPE_PRE_ACCESS_TOKEN_CREATION"
            actionIds = [_actionId]
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef.name = spec.providerConfigsRef.zitadelProviderName
    }
}

_items = [_observe_zitadel_admin_sa, _script_cm, _zitadelPostConfigInit, _job_sa, _job_role, _job_rb, _observe_zitadel_org_secret, _human_admin_password_secret, _zitadelAdminHumanUser, _zitadelInstanceMember, _zitadelOrgMember, _zitadelActionFlatRoles, _zitadelTriggerPreUserInfo, _zitadelTriggerPreAccessToken, _adminUserIdOutputSecret]
items = _items + [oxr]