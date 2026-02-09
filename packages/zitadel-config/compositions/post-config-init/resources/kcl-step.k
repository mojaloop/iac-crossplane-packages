import json
import base64
import regex as re

# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

# Observe Zitadel admin sa secret
_observe_zitadel_admin_sa = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-zitadel-admin-sa-observe".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "zitadel-admin-sa-observe"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "Secret"
                metadata = {
                    name = parameters.zitadelAdminSecret.name
                    namespace = spec.claimRef?.namespace or "zitadel"
                }
            }
        }
        managementPolicies = ["Observe"]
        providerConfigRef = {
            name = spec.providerConfigsRef.kubernetesProviderName
        }
    }

}

# 1. Decode base64 from the Observed Secret
# The ocds["zitadel-admin-sa"] is the Crossplane Observed Connection Detail
_raw_data = ocds["zitadel-admin-sa-observe"]?.Resource?.status?.atProvider?.manifest?.data?[parameters.zitadelAdminSecret.key] or ""

# 2. Parse the inner JSON content
# We decode the base64, then decode the resulting JSON string into a KCL object
_zitadelAdminSa = json.decode(base64.decode(_raw_data)) if _raw_data else {}

# 3. Extract the specific variables
# Note: Using .get() or ? to handle cases where ZITADEL hasn't populated the secret yet
user_id = _zitadelAdminSa.userId or ""
key_id = _zitadelAdminSa.keyId or ""
# We fix the escaped newlines in the private key to ensure it's a valid PEM format for openssl
private_key = (_zitadelAdminSa.key or "").replace("\\n", "\n")


_script = """
set -e
echo "Waiting for {DOMAIN}..."
until curl -skf "{DOMAIN}/debug/healthz"; do sleep 5; done

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

  TOKEN=$(curl -s -X POST "{DOMAIN}/oauth/v2/token" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    -d "scope=openid urn:zitadel:iam:org:project:id:zitadel:aud" \
    -d "assertion=$HEADER.$PAYLOAD.$SIG" | grep -oP '(?<="access_token":")[^"]*')

  if [ -n "$TOKEN" ]; then
    ORG_ID=$(curl -s -H "Authorization: Bearer $TOKEN" "{DOMAIN}/admin/v1/orgs/default" | grep -oP '(?<="id":")[^"]*')
    if [ -n "$ORG_ID" ]; then
      echo "FOUND_ORG_ID=$ORG_ID"
      # We output this so Crossplane can capture it or we write to a secret
      exit 0
    fi
  fi
  echo "Attempt $i failed, retrying..."
  sleep 10
done
exit 1
""".format(
    DOMAIN = parameters.domain,
    UID = user_id,
    KID = key_id,
    PRIV_KEY = private_key
)

_zitadelPostConfigInit = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-post-config-job".format(oxr.metadata.name)
        annotations = {"krm.kcl.dev/composition-resource-name": "post-config-job"}
    }
    spec = {
        forProvider.manifest = {
            apiVersion = "batch/v1"
            kind = "Job"
            metadata = {
                name = "{}-getter".format(oxr.metadata.name)
                namespace = parameters.namespace or "zitadel"
            }
            spec.template.spec = {
                containers = [{
                    name = "zitadel-helper"
                    image = "alpine:latest"
                    command = ["/bin/sh", "-c", "apk add --no-cache curl openssl && " + _script]
                }]
                restartPolicy = "Never"
            }
        }
        providerConfigRef.name = spec.providerConfigsRef.kubernetesProviderName
    }
}

# 4. Final Items list
_items = [_observe_zitadel_admin_sa, _zitadelPostConfigInit]

dxr = {
    **oxr
}

items = _items + [dxr]
