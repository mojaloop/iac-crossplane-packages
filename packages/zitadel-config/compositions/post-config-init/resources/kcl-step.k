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
  IAT=$(($(date +%s) - 60))
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

      # --- K8S SECRET CREATION ---
      K8S_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

      echo "Creating Secret {OUT_SECRET}..."

      # Encode the Org ID to Base64 for the Secret
      ORG_B64=$(echo -n "$ORG_ID" | base64)

      curl -s -X POST "https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/secrets" \\
        --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \\
        -H "Authorization: Bearer $K8S_TOKEN" \\
        -H "Content-Type: application/json" \\
        -d @- <<EOF
{{
  "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {{
    "name": "{OUT_SECRET}"
  }},
  "data": {{
    "{OUT_KEY}": "$ORG_B64"
  }}
}}
EOF
      exit 0
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
                # Ensure the Job has permission to create secrets
                # You may need to bind a Role to this default ServiceAccount
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

_sa_name = "{}-getter-sa".format(metadata.name)

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
                name = "{}-secret-creator".format(metadata.name)
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
                name = "{}-secret-creator-binding".format(metadata.name)
                namespace = namespace
            }
            roleRef = {
                apiGroup = "rbac.authorization.k8s.io"
                kind = "Role"
                name = "{}-secret-creator".format(metadata.name)
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

_items = [_observe_zitadel_admin_sa, _script_cm, _job_sa, _job_role,_job_rb, _zitadelPostConfigInit]
items = _items + [oxr]