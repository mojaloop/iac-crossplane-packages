# ObjectStoreUser Crossplane Package

Objectstoreuser crossplane package provides custom compositions to support user provisioning for both Ceph (private-cloud) and AWS S3 (cloud) object storage providers.

## Installation

To install the objectstoreuser composition package:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: objectstoreuser
spec:
  package: ghcr.io/mojaloop/iac-crossplane-packages/objectstoreuser:VERSION
```

## Available Compositions

This package includes the following compositions:

1. [CephBucketUser](compositions/ceph-user/README.md) - Creates Ceph bucket users with Rook CRD
2. [IAMUser](compositions/iam-user/README.md) - Creates AWS IAM users with access keys
3. [ObjectStoreUser](compositions/object-store-user/README.md) - Cloud-agnostic composition that routes to Ceph or IAM

## Quick Start

### Ceph User Example

```yaml
apiVersion: objectstore.mojaloop.io/v1alpha1
kind: ObjectStoreUser
metadata:
  name: gitlab-backup-user
  namespace: gitlab
spec:
  parameters:
    objectStoreProvider: ceph
    userName: gitlab-backup-user
    displayName: "GitLab Backup User"
    namespace: gitlab
    ceph:
      operationMask:
        - read
        - write
        - delete
      rookNamespace: rook-ceph
```

### IAM User Example

```yaml
apiVersion: objectstore.mojaloop.io/v1alpha1
kind: ObjectStoreUser
metadata:
  name: gitlab-backup-user
  namespace: gitlab
spec:
  parameters:
    objectStoreProvider: s3
    userName: gitlab-backup-user
    displayName: "GitLab Backup User"
    namespace: gitlab
    iam:
      tags:
        - key: Environment
          value: production
```

## Features

- **Cloud-agnostic API**: Single `ObjectStoreUser` resource that works with both Ceph and IAM
- **Automatic Kubernetes Secrets**: Credentials are automatically stored in Kubernetes secrets
- **Configurable Operations**: For Ceph users, operations mask (read/write/delete) is configurable
- **Provider Routing**: KCL function intelligently routes to appropriate provider composition
- **Namespace Support**: Secrets created in specified namespace

## Parameters

### Common Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `objectStoreProvider` | string | Yes | `ceph`, `s3`, or `aws` |
| `userName` | string | Yes | Username for the object store user |
| `displayName` | string | Yes | Display name for the user |
| `namespace` | string | Yes | Kubernetes namespace for storing credentials |
| `ccK8sProviderName` | string | No | Control center K8s provider config (default: `kubernetes-provider`) |

### Ceph-Specific Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ceph.operationMask` | array | `[read, write, delete]` | Allowed operations |
| `ceph.rookNamespace` | string | `rook-ceph` | Rook Ceph installation namespace |
| `ceph.storeName` | string | `default` | Ceph ObjectStore name |
| `scK8sProviderName` | string | `sc-kubernetes-provider` | Storage cluster K8s provider config |

### IAM-Specific Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `awsProviderName` | string | `aws-cp-upbound-provider-config` | AWS IAM provider config |
| `iam.tags` | array | `[]` | AWS tags to apply to IAM user |

## Outputs

### Ceph User
- Creates CephObjectStoreUser resource in Rook Ceph namespace
- Stores credentials in Kubernetes secret: `{username}-ceph-secret`
- Secret contains: `username`, `access_key`, `secret_key`

### IAM User
- Creates IAM User in AWS account
- Creates Access Key for programmatic access
- Stores credentials in Kubernetes secret: `{username}-iam-secret`
- Secret contains: `accesskeyid`, `secretaccesskey`

## Testing

Example claims are located in `test/scenarios/`:

- `ceph-user-claim.yaml` - Create a Ceph bucket user
- `iam-user-claim.yaml` - Create an IAM user

Apply with:
```bash
kubectl apply -f test/scenarios/ceph-user-claim.yaml
```

## Architecture

```
ObjectStoreUser (main claim/XR)
    ↓
KCL Routing Function
    ├── if provider == "ceph" → XCephBucketUser composition
    │   ├── CephObjectStoreUser resource (Rook CRD)
    │   └── Kubernetes Secret (credentials)
    └── if provider == "s3"/"aws" → XIAMUser composition
        ├── IAM User resource
        ├── IAM Access Key resource
        └── Kubernetes Secret (credentials)
```

## Status & Observability

Monitor composition status:
```bash
kubectl get objectstoreusers
kubectl describe objectstoreuser <name>
kubectl get secret <username>-<provider>-secret -o yaml
```

## Troubleshooting

### User creation stuck in pending
- Check KCL function status: `kubectl get functions`
- Verify provider configs exist and are accessible
- Review controller logs: `kubectl logs -n crossplane-system deployment/crossplane`

### Secret not created
- Verify namespace exists and is accessible to providers
- Check Kubernetes provider config authentication
- Review provider logs for access denied errors

### For Ceph: CephObjectStoreUser not created
- Verify Rook Ceph cluster is running: `kubectl get cephclusters -n rook-ceph`
- Check ObjectStore exists: `kubectl get cephobjectstores -n rook-ceph`
- Verify Rook namespace parameter matches installation

### For IAM: User not created in AWS
- Verify AWS credentials in provider config
- Check IAM permissions include CreateUser, CreateAccessKey
- Review AWS CloudTrail logs for detailed error information

## Usage with ObjectStore Buckets

This package creates users with credentials. To configure bucket access:

1. Create user with `ObjectStoreUser`
2. Obtain credentials from generated secret
3. Configure bucket policies in your `ObjectStore` resource to include the user ARN (AWS) or user ID (Ceph)

Example bucket policy referencing a GitLab-created IAM user:

```yaml
bucketPolicy:
  Statement:
    - Effect: Allow
      Principal:
        AWS: arn:aws:iam::123456789012:user/gitlab-backup-user
      Action:
        - s3:GetObject
        - s3:PutObject
      Resource: arn:aws:s3:::my-bucket/*
```

## License

This package is licensed under the same license as the Mojaloop project.
