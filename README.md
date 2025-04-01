# Crossplane Composition Packages

This repository contains Crossplane composition packages that define reusable infrastructure components and configurations.

## Overview

This project provides a collection of Crossplane composition packages designed to streamline infrastructure provisioning and management. These packages offer reusable components that can be easily integrated into your infrastructure-as-code workflows.

## Packages

- [Utils](packages/utils/README.md) - Common utility compositions
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

## License

This project is licensed under [LICENSE](LICENSE.md) - see the LICENSE file for details.
