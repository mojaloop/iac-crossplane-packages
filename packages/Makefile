COMPOSITION_NAME ?=
PACKAGE_NAME ?=

PACKAGE_DIR := $(PACKAGE_NAME)
COMPOSITION_DIR := $(PACKAGE_DIR)/compositions
CONFIG_DIR := $(PACKAGE_DIR)/configuration
RESOURCES_DIR := $(COMPOSITION_DIR)/$(COMPOSITION_NAME)/resources
TEST_DIR := $(COMPOSITION_DIR)/$(COMPOSITION_NAME)/test
TESTSCENARIOS_DIR := $(TEST_DIR)/scenarios
RENDERED_DIR := $(COMPOSITION_DIR)/$(COMPOSITION_NAME)/rendered
EXTENSIONS_DIR := $(RENDERED_DIR)/extensionsDir

COMPOSITION_FILE := $(RESOURCES_DIR)/composition.yaml
DEFINITION_FILE := $(RESOURCES_DIR)/definition.yaml
KCL_FILE := $(RESOURCES_DIR)/kcl-step.k
COMPOSITION_OUTPUT := $(RENDERED_DIR)/composition.yaml
DEFINITION_OUTPUT := $(RENDERED_DIR)/definition.yaml
FUNCTIONS_FILE := $(TEST_DIR)/functions.yaml
OBSERVED_FILE := $(TESTSCENARIOS_DIR)/observed.yaml
EXTRA_RESOURCES_FILE := $(TESTSCENARIOS_DIR)/extra.yaml
LOCAL_COMPOSITIONS_FILE := $(TEST_DIR)/local-compositions.yaml

TESTSCENARIO ?=
CLAIM_FILE ?=

CROSSPLANE_RENDER_CMD := $(shell if crossplane render --help > /dev/null 2>&1; then echo "crossplane render"; else echo "crossplane beta render"; fi)
CROSSPLANE_VALIDATE_CMD := $(shell if crossplane resource validate --help > /dev/null 2>&1; then echo "crossplane resource validate"; else echo "crossplane beta validate"; fi)

EXTRA_RENDER_ARGS ?=
EXTRA_VALIDATE_ARGS ?=

# =============================================================================

# Default target
.PHONY: all
all: validate_dir process_all_compositions

# Validate directory exists
.PHONY: validate_dir
validate_dir:
	@echo "⚙️  Verifying composition structure..."
	@[ -n "$(PACKAGE_NAME)" ] || { echo "❗ Critical: PACKAGE_NAME is required."; exit 1; }
	@[ -d $(PACKAGE_DIR) ] || { echo "❗ Critical: Package directory '$(PACKAGE_DIR)' not found."; exit 1; }
	@[ -d $(COMPOSITION_DIR) ] || { echo "❗ Critical: Compositions directory '$(COMPOSITION_DIR)' not found."; exit 1; }

# Process all compositions
.PHONY: process_all_compositions
process_all_compositions:
	@echo "🔁 Batch processing compositions in $(COMPOSITION_DIR)..."
	@dirs=$$(find $(COMPOSITION_DIR) -maxdepth 1 -mindepth 1 -type d); \
	[ -n "$$dirs" ] || { echo "❗ Critical: No composition directories found in '$(COMPOSITION_DIR)'."; exit 1; }; \
	for dir in $$dirs; do \
		$(MAKE) package_composition COMPOSITION_NAME=$$(basename $$dir) PACKAGE_NAME=$(PACKAGE_NAME); \
	done

# Build & Render Targets
.PHONY: generate
generate:
	@echo "\n🔧 Constructing Crossplane configuration..."
	@mkdir -p $(RENDERED_DIR)

	@if [ -f $(COMPOSITION_FILE) ]; then \
		if grep -q '\$$KCL_FUNCTION_CODE' $(COMPOSITION_FILE); then \
			if [ -f $(KCL_FILE) ]; then \
				echo "📄 Inserting KCL function code from $(KCL_FILE)..."; \
				awk ' \
					BEGIN { \
						replacing=0; \
						indent=""; \
					} \
					/\$$KCL_FUNCTION_CODE/ { \
						replacing=1; \
						indent=substr($$0, 1, match($$0, /[^ ]/) - 1); \
						print indent "# Start of KCL function code"; \
						while ((getline line < "$(KCL_FILE)") > 0) { \
							print indent line; \
						} \
						print indent "# End of KCL function code"; \
						next; \
					} \
					{ print $$0; }' $(COMPOSITION_FILE) > $(COMPOSITION_OUTPUT); \
				echo "✨ $(COMPOSITION_OUTPUT) created with KCL code"; \
			else \
				echo "⚠️  Warning: KCL file '$(KCL_FILE)' not found. Skipping KCL code insertion."; \
				cp $(COMPOSITION_FILE) $(COMPOSITION_OUTPUT); \
			fi; \
		else \
			echo "📋 Source configuration imported to $(COMPOSITION_OUTPUT)"; \
			cp $(COMPOSITION_FILE) $(COMPOSITION_OUTPUT); \
		fi; \
	else \
		echo "❗ Critical: Source configuration $(COMPOSITION_FILE) not found"; \
		exit 1; \
	fi

	@if [ -f $(DEFINITION_FILE) ]; then \
		cp $(DEFINITION_FILE) $(DEFINITION_OUTPUT); \
		echo "📋 Definition specification imported to $(DEFINITION_OUTPUT)"; \
	else \
		echo "⚠️  Advisory: Definition specification $(DEFINITION_FILE) not found"; \
	fi

	@echo "✅ Construction phase complete"

# Render function - handles all cases
.PHONY: render
render: generate
	@echo "\n⚡ Processing composition templates..."
	@mkdir -p $(RENDERED_DIR)

	@if [ -n "$(CLAIM_FILE)" ]; then \
		$(call render_specific_claim,$(CLAIM_FILE),claim); \
	elif [ -n "$(TESTSCENARIO)" ] && [ -f "$(TESTSCENARIOS_DIR)/$(TESTSCENARIO)/claim.yaml" ]; then \
		$(call render_testscenario,$(TESTSCENARIO)); \
	elif [ -d "$(TESTSCENARIOS_DIR)" ]; then \
		$(call render_all_testscenarios); \
	elif [ -f "$(TESTSCENARIOS_DIR)/claim.yaml" ]; then \
		$(call render_specific_claim,$(TESTSCENARIOS_DIR)/claim.yaml,default); \
	else \
		echo "❗ Critical: No valid rendering configuration found"; \
		echo "   Required: either CLAIM_FILE, TESTSCENARIO, scenarios directory, or default claim.yaml"; \
		exit 1; \
	fi

	@echo "✅ Template processing complete"

# Define rendering functions
# -----------------------------------------------------------------------------
define render_specific_claim
	output_file="$(RENDERED_DIR)/rendered_$(2).yaml"; \
	echo "📄 Processing configuration: $(1)"; \
	if [ -f "$$output_file" ]; then \
		echo "🧹 Cleaning up previous render: $$output_file"; \
		rm -f "$$output_file"; \
	fi; \
	observed=""; \
	if [ -f "$(dir $(1))observed.yaml" ]; then \
		echo "📊 Including runtime state data"; \
		observed="-o $(dir $(1))observed.yaml"; \
	elif [ -f "$(OBSERVED_FILE)" ]; then \
		echo "📊 Including global runtime state"; \
		observed="-o $(OBSERVED_FILE)"; \
	fi; \
	extra_resources=""; \
	if [ -f "$(dir $(1))extra.yaml" ]; then \
		echo "📋 Including scenario extra resources"; \
		extra_resources="--extra-resources $(dir $(1))extra.yaml"; \
	elif [ -f "$(EXTRA_RESOURCES_FILE)" ]; then \
		echo "📋 Including global extra resources"; \
		extra_resources="--extra-resources $(EXTRA_RESOURCES_FILE)"; \
	fi; \
	$(CROSSPLANE_RENDER_CMD) "$(1)" $(COMPOSITION_OUTPUT) $(FUNCTIONS_FILE) $$observed $$extra_resources -x $(EXTRA_RENDER_ARGS) > "$$output_file" 2>&1 || { cat "$$output_file" >&2; exit 1; }; \
	echo "💾 Template output: $$output_file"
endef

define render_testscenario
	echo "📌 Executing testscenario: $(1)"; \
	$(call render_specific_claim,$(TESTSCENARIOS_DIR)/$(1)/claim.yaml,$(1))
endef

define render_all_testscenarios
	echo "📚 Executing all testscenarios..."; \
	for scenario_dir in $(TESTSCENARIOS_DIR)/*; do \
		if [ -d "$$scenario_dir" ] && [ -f "$$scenario_dir/claim.yaml" ]; then \
			scenario_name=$$(basename "$$scenario_dir"); \
			echo "\n📌 Executing testscenario: $$scenario_name"; \
			$(call render_specific_claim,$$scenario_dir/claim.yaml,$$scenario_name); \
		fi; \
	done
endef

# Validation process
.PHONY: validate
validate: render
	@echo "\n🔎 Initiating validation sequence..."
	@mkdir -p $(EXTENSIONS_DIR)

	@# Setup extensions directory
	@echo "📂 Preparing validation environment..."
	@cp $(COMPOSITION_OUTPUT) $(EXTENSIONS_DIR)/composition.yaml
	@cp $(DEFINITION_OUTPUT) $(EXTENSIONS_DIR)/definition.yaml

	@# Process local compositions if available
	@if [ -f $(LOCAL_COMPOSITIONS_FILE) ] && command -v yq >/dev/null 2>&1; then \
		echo "🔗 Incorporating dependencies..."; \
		compositions=$$(yq e '.compositionFolders[]' $(LOCAL_COMPOSITIONS_FILE) 2>/dev/null); \
		for comp in $$compositions; do \
			comp_def="$(COMPOSITION_DIR)/$$comp/resources/definition.yaml"; \
			if [ -f "$$comp_def" ]; then \
				cp "$$comp_def" "$(EXTENSIONS_DIR)/$${comp}_definition.yaml"; \
				echo "✓ Registered dependency: $$comp"; \
			else \
				echo "⚠️  Advisory: Dependency specification not found at $$comp_def"; \
			fi; \
		done; \
	fi

	@# Copy additional configuration files if they exist
	@if [ -f $(TEST_DIR)/providers.yaml ]; then \
		cp $(TEST_DIR)/providers.yaml $(EXTENSIONS_DIR)/providers.yaml; \
		echo "📋 Provider configuration registered"; \
	fi

	@if [ -f $(TEST_DIR)/packages.yaml ]; then \
		cp $(TEST_DIR)/packages.yaml $(EXTENSIONS_DIR)/packages.yaml; \
		echo "📋 Package configuration registered"; \
	fi

	@echo "\n🔬 Executing validation checks..."

	@# Validate specific or all files
	@if [ -n "$(CLAIM_FILE)" ]; then \
		$(call validate_file,"$(RENDERED_DIR)/rendered_claim.yaml"); \
	elif [ -n "$(TESTSCENARIO)" ]; then \
		$(call validate_file,"$(RENDERED_DIR)/rendered_$(TESTSCENARIO).yaml"); \
	else \
		for rendered in $(RENDERED_DIR)/rendered_*.yaml; do \
			if [ -f "$$rendered" ]; then \
				$(call validate_file,"$$rendered"); \
				echo ""; \
			fi; \
		done; \
	fi

	@echo "✅ Validation sequence complete"

# Define validation function
# -----------------------------------------------------------------------------
define validate_file
	echo "🧪 Analyzing: $(1)"; \
	$(CROSSPLANE_VALIDATE_CMD) $(EXTENSIONS_DIR) "$(1)" --cache-dir="$(COMPOSITION_DIR)/$(COMPOSITION_NAME)/.crossplane/cache" $(EXTRA_VALIDATE_ARGS) | \
		sed -e 's/\[✓\]/\x1b[32m[✓]\x1b[0m/g' \
			-e 's/\[×\]/\x1b[31m[×]\x1b[0m/g' \
			-e 's/\[!\]/\x1b[33m[!]\x1b[0m/g' \
			-e 's/validated successfully/\x1b[32mvalidated successfully\x1b[0m/g' \
			-e 's/validation failed/\x1b[31mvalidation failed\x1b[0m/g' \
			-e 's/Kind=/\x1b[36mKind=\x1b[0m/g' \
			-e 's/Total \([0-9]*\) resources:/\x1b[1;34mTotal \1 resources:\x1b[0m/g'
endef

# Package the composition
.PHONY: package_composition
package_composition: validate
	@echo "📦 Building deployment package for $(PACKAGE_NAME)/$(COMPOSITION_NAME)..."
	@mkdir -p $(CONFIG_DIR)/$(COMPOSITION_NAME)
	@cp $(COMPOSITION_OUTPUT) $(CONFIG_DIR)/$(COMPOSITION_NAME)/composition.yaml
	@cp $(DEFINITION_OUTPUT) $(CONFIG_DIR)/$(COMPOSITION_NAME)/definition.yaml
	@echo "✅ Deployment package assembled successfully"

# Apply composition and definition files
.PHONY: apply
apply: render
	@echo "🚀 Deploying resources to Kubernetes..."
	@kubectl apply -f $(DEFINITION_OUTPUT) && kubectl apply -f $(COMPOSITION_OUTPUT)
	@echo "✅ Deployment successful"

# Clean up
.PHONY: clean
clean:
	@echo "♻️  Purging generated artifacts..."
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "❗ Critical: PACKAGE_NAME is required."; \
		exit 1; \
	fi; \
	if [ -n "$(COMPOSITION_NAME)" ]; then \
		echo "🧹 Removing rendered files for $(PACKAGE_NAME)/$(COMPOSITION_NAME)..."; \
		rm -rf $(COMPOSITION_DIR)/$(COMPOSITION_NAME)/rendered; \
		rm -rf $(CONFIG_DIR)/$(COMPOSITION_NAME); \
	else \
		echo "🧹 Removing all rendered files and configurations..."; \
		find $(PACKAGE_DIR) -type d -name "rendered" -exec rm -rf {} \; 2>/dev/null || true; \
		find $(CONFIG_DIR) -mindepth 1 -not -name "crossplane.yaml" -exec rm -rf {} \; 2>/dev/null || true; \
	fi
	@echo "✅ Workspace sanitized"

.PHONY: help
help:
	@echo "Crossplane Composition Development Tooling"
	@echo "===================================="
	@echo ""
	@echo "Usage:"
	@echo "  make [target] [PACKAGE_NAME=name] [COMPOSITION_NAME=name] [TESTSCENARIO=name] [CLAIM_FILE=path]"
	@echo ""
	@echo "Primary Targets:"
	@echo "  all                    Process all compositions (default)"
	@echo "  generate               Construct configuration from resources"
	@echo "  render                 Process templates into final form"
	@echo "  validate               Verify configuration correctness"
	@echo "  package_composition    Assemble deployment package"
	@echo "  apply                  Deploy configuration to Kubernetes"
	@echo "  clean                  Remove all generated artifacts"
	@echo "  help                   Display this control panel"
	@echo ""
	@echo "Parameters:"
	@echo "  PACKAGE_NAME           Package identifier (required)"
	@echo "  COMPOSITION_NAME       Target composition identifier"
	@echo "  TESTSCENARIO           Specific testing scenario to execute"
	@echo "  CLAIM_FILE             Path to custom claim specification"
	@echo "  EXTRA_RENDER_ARGS      Additional template processing parameters"
	@echo "  EXTRA_VALIDATE_ARGS    Additional validation parameters"
