# Crossplane Composition Packages

This repository contains Crossplane composition packages that define reusable infrastructure components and configurations.

## Overview

This project provides a collection of Crossplane composition packages designed to streamline infrastructure provisioning and management. These packages offer reusable components that can be easily integrated into your infrastructure-as-code workflows.

## Packages

- [Utils](packages/utils/README.md) - Common utility compositions
- [Storage Cluster Bootstrap](packages/sc-bootstrap/README.md) - Storage Cluster Bootstrap composition
- [Storage Cluster Postgres Cluster](packages/sc-pgcluster/README.md) - Storage Cluster Postgres Cluster composition
- [AWS DocDbCluster](packages/aws-docdbcluster/README.md) - Storage Cluster Postgres Cluster composition
- [AWS S3 Bucket](packages/aws-s3bucket/README.md) - AWS S3 Bucket composition
- Additional packages coming soon...

## Getting Started

### Prerequisites

- Kubernetes cluster
- Crossplane installed and configured
- Required provider and functions installed and configured

### Installation

Installation is described in each package

### Development

The project includes a comprehensive Makefile to help with composition development and testing:

The Makefile serves a crucial role in managing Crossplane compositions that use separated KCL function code. While Crossplane typically expects function code to be inline within compositions, our project separates KCL code into dedicated files for better maintainability and reusability. The Makefile:

- Automatically injects KCL function code from separate `.k` files into compositions during the build process
- Maintains the separation of concerns between composition structure and function logic
- Handles the preprocessing step needed to create valid Crossplane compositions with embedded KCL code
- Manages the build pipeline from separate files to deployable configurations

This approach allows developers to:
- Write and maintain KCL functions in dedicated files
- Reuse function code across multiple compositions
- Keep compositions cleaner and more focused on structure
- Leverage better tooling support for KCL development

#### Validation
Use `make validate` to verify your composition configurations:
```bash
make validate PACKAGE_NAME=<package> COMPOSITION_NAME=<composition>
```
This will:
- Process and render your composition templates
- Set up a validation environment with required dependencies
- Run validation checks against the rendered configurations
- Display detailed validation results with color-coded status indicators

#### Deployment
Use `make apply` to deploy compositions to your Kubernetes cluster:
```bash
make apply PACKAGE_NAME=<package> COMPOSITION_NAME=<composition>
```
This will:
- Render your composition templates
- Apply the composition and definition files to your Kubernetes cluster using kubectl

Both commands support additional parameters:
- `TESTSCENARIO`: Specify a test scenario to validate
- `EXTRA_RENDER_ARGS`: Additional template processing parameters
- `EXTRA_VALIDATE_ARGS`: Additional validation parameters

#### Commit and Branch Conventions

This project follows strict commit message and branch naming conventions:

##### Commit Messages
We use [Conventional Commits](https://www.conventionalcommits.org/) specification for commit messages. Each commit message must be structured as follows:

#### Versioning

Each package in this repository follows semantic versioning (SemVer) with package-specific version tracking. The versioning system:

- Uses semantic versioning (MAJOR.MINOR.PATCH)
- Maintains separate version numbers for each package
- Creates git tags in the format `packagename/vX.Y.Z` (e.g., `utils/v1.0.0`)

Version increments are determined automatically based on commit messages:
- `fix:` commits trigger PATCH updates (e.g., v1.0.0 → v1.0.1)
- `feat:` commits trigger MINOR updates (e.g., v1.0.0 → v1.1.0)
- `feat!:` or `BREAKING CHANGE:` commits trigger MAJOR updates (e.g., v1.0.0 → v2.0.0)

Development workflow:
1. Create a pull request with your changes
2. During PR validation, packages are built with temporary versions:
   - Format: `vX.Y.Z-pr{number}-{runid}`
   - Example: `v1.0.0-pr123-456789`
   - These versions can be used for testing

Release process:
1. Review and approve pull request
2. Merge PR into main branch
3. The CI/CD pipeline automatically:
   - Calculates the next semantic version based on commit history
   - Builds and validates the package
   - Creates a git tag (e.g., `packagename/v1.0.0`)
   - Pushes the package to the registry with the final version

## License

This project is licensed under [LICENSE](LICENSE.md) - see the LICENSE file for details.

### Debugging and Troubleshooting

#### Debugging KCL Functions

To debug KCL functions in your compositions, follow these steps:

1. Clone and run the function-kcl locally:
```bash
# Clone the function-kcl repository
git clone https://github.com/crossplane-contrib/function-kcl.git
cd function-kcl

# Run the function locally in debug mode
go run . --insecure --debug
```

2. In your `functions.yaml`, ensure you're using the development runtime annotation:
```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-kcl
  annotations:
    render.crossplane.io/runtime: Development
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-kcl:latest
```

3. In another terminal, validate your composition using the make command:
```bash
make validate PACKAGE_NAME=<package> COMPOSITION_NAME=<composition>
```

This will:
- Process and render your composition templates
- Set up a validation environment
- Connect to your locally running function-kcl
- Display detailed validation results
