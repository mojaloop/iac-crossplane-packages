# S3 Bucket Composition

This composition creates and manages an AWS S3 bucket with the following resources:
- S3 Bucket
- Bucket ACL (set to private)
- Bucket Ownership Controls (set to BucketOwnerPreferred)
- Bucket Policy with appropriate permissions
- IAM User with access key

## Usage Examples

The following test scenarios demonstrate common use cases:

1. [Standard S3 Bucket](test/scenarios/standard/claim.yaml)

### Provider Configuration

Both provider configurations must be present on the cluster where the claim is deployed:

```yaml
providerConfigsRef:
  awsProviderName: AWS_PROVIDER_CONFIG_NAME
```
