# Gitlab Post Config Composition

TBD

## Usage Examples

The following test scenarios demonstrate common use cases:

1. [Standard Gitlab Post Configuration](test/scenarios/standard/claim.yaml)

## Configuration

The GitLab CI PAT is managed by a composed `groups.gitlab.crossplane.io/v1alpha1`
`AccessToken`. Rotation is delegated to provider-gitlab through:

- `spec.parameters.ciTokenRenewalPeriodDays`
- `spec.parameters.ciTokenRenewBeforeDays`

The composition intentionally does not calculate or persist a fixed `expiresAt`.
Provider-gitlab must expose `renewalPeriodDays` and `renewBeforeDays` on
`AccessToken`; older provider versions only support fixed `expiresAt` and do not
rotate token values.

## Provider Configuration

Requires provider-gitlab `>=v0.18.1` for provider-managed token renewal.
The validation fixture and runtime deployment use the Mojaloop GHCR mirror, so
`ghcr.io/mojaloop/infra/crossplane-contrib/provider-gitlab:v0.18.1` must exist
before deploying this composition.
