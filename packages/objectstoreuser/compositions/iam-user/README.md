# IAMUser Composition

This composition creates an AWS IAM user with access keys and stores credentials in Kubernetes.

## Resources Created

- `iam.aws.upbound.io/User` - AWS IAM user
- `iam.aws.upbound.io/AccessKey` - AWS programmatic access key
- Kubernetes `Secret` - Contains access credentials

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `userName` | string | Yes | AWS IAM username |
| `displayName` | string | Yes | Display name (for metadata) |
| `namespace` | string | Yes | K8s namespace for secret |
| `awsProviderName` | string | Yes | AWS IAM provider config name |
| `k8sProviderName` | string | Yes | Kubernetes provider config name |
| `tags` | array | No | AWS tags (key/value pairs) |

## Example

```yaml
apiVersion: objectstore.mojaloop.io/v1alpha1
kind: IAMUser
metadata:
  name: gitlab-backup-user
spec:
  parameters:
    userName: gitlab-backup-user
    displayName: "GitLab Backup User"
    namespace: gitlab
    awsProviderName: aws-cp-upbound-provider-config
    k8sProviderName: kubernetes-provider
    tags:
      - key: Application
        value: gitlab
      - key: Environment
        value: production
```

## Generated Secret

The secret `{username}-iam-secret` will contain:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-backup-user-iam-secret
  namespace: gitlab
type: Opaque
data:
  accesskeyid: <base64-encoded-access-key-id>
  secretaccesskey: <base64-encoded-secret-access-key>
```

## AWS Permissions Required

The AWS provider config must have permissions to:
- `iam:CreateUser`
- `iam:CreateAccessKey`
- `iam:TagUser` (if tags are specified)
- `iam:GetUser`
- `iam:DeleteUser` (for cleanup)
- `iam:DeleteAccessKey` (for cleanup)
