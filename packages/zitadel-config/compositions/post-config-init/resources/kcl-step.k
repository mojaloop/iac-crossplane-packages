import json
import base64

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

# 3. Define the Script (Fixed for BusyBox/Alpine using sed)
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
  PAYLOAD=$(echo -n '{{"iss":"{UID}","sub":"{UID}","aud":"{DOMAIN}","iat":'$IAT',"exp":'$EXP'}}' | b64url)
  SIG=$(echo -n "$HEADER.$PAYLOAD" | openssl dgst -sha256 -sign /tmp/privkey.pem -binary | b64url)

  RESPONSE=$(curl -s -X POST "https://{DOMAIN}/oauth/v2/token" \\
    -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \\
    -d "scope=openid urn:zitadel:iam:org:project:id:zitadel:aud" \\
    -d "assertion=$HEADER.$PAYLOAD.$SIG")

  # BusyBox fix: Use sed instead of grep -oP
  TOKEN=$(echo "$RESPONSE" | sed -n 's/.*"access_token":"\\([^"]*\\)".*/\\1/p')

  if [ -n "$TOKEN" ]; then
    ORG_ID_RAW=$(curl -s -H "Authorization: Bearer $TOKEN" "https://{DOMAIN}/admin/v1/orgs/default")
    ORG_ID=$(echo "$ORG_ID_RAW" | sed -n 's/.*"id":"\\([^"]*\\)".*/\\1/p')
    if [ -n "$ORG_ID" ]; then
      echo "FOUND_ORG_ID=$ORG_ID"
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
    PRIV_KEY = private_key
)

# 4. ConfigMap to store the script
_script_cm = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-script-cm".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "script-cm"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "v1"
            kind = "ConfigMap"
            metadata = {
                name = "{}-getter-script".format(metadata.name)
                namespace = namespace
            }
            data = {"fetch-org.sh" = _script_content}
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

# 5. Post-Config Init Job (Mounted ConfigMap)
_zitadelPostConfigInit = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-post-config-job".format(metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "post-config-job"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "batch/v1"
            kind = "Job"
            metadata = {
                name = "{}-getter".format(metadata.name)
                namespace = namespace
            }
            spec.template.spec = {
                containers = [{
                    name = "zitadel-helper"
                    image = "alpine:latest"
                    # Add apk dependencies then run the mounted script
                    command = ["/bin/sh", "-c", "apk add --no-cache curl openssl && sh /scripts/fetch-org.sh"]
                    volumeMounts = [{
                        name = "script-vol"
                        mountPath = "/scripts"
                    }]
                }]
                restartPolicy = "Never"
                volumes = [{
                    name = "script-vol"
                    configMap = {
                        name = "{}-getter-script".format(metadata.name)
                        defaultMode = 0o755
                    }
                }]
            }
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

_items = [_observe_zitadel_admin_sa, _script_cm, _zitadelPostConfigInit]
dxr = {**oxr}
items = _items + [dxr]