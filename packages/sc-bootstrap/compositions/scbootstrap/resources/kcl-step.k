# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds
extra = option("params")?.ctx["apiextensions.crossplane.io/extra-resources"]

spec = oxr.spec
parameters = spec.parameters

# Initialize the items list
_items = []

# Calico Helm Chart install
_calicoHelmChart = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "{}-calico".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "calico-helm-chart"
        }
    }
    spec = {
        forProvider = {
            chart = {
                name = "tigera-operator"
                repository = "https://docs.tigera.io/calico/charts"
                version = parameters?.calico?.chartVersion
            }

            wait = True
            namespace = "tigera-operator"
            values = parameters?.calico?.values
        }
        managementPolicies = ["Create", "Observe"]
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scHelmProviderName
        }
    }
}

# ArgoCD Helm Chart install
_argocdHelmChart = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "argocd-release"
        annotations = {
            "krm.kcl.dev/composition-resource-name": "argocd-helm-chart"
        }
    }
    spec = {
        forProvider = {
            chart = {
                name = "argo-cd"
                repository = "https://argoproj.github.io/argo-helm"
                version = parameters?.argocd?.chartVersion
            }
            namespace = "argocd"
            wait = True
            values = parameters?.argocd?.values
        }
        managementPolicies = ["Create", "Observe"]
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scHelmProviderName
        }
    }
}

# ArgoCD Root application installation
_Application = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-app".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "root-application"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "argoproj.io/v1alpha1"
                kind = "Application"
                metadata = {
                    name = "root-deployer"
                    namespace = "argocd"
                }
                spec = {
                    destination = {
                        namespace = "argocd"
                        server = "https://kubernetes.default.svc"
                    }
                    project = "default"
                    syncPolicy = {
                        automated = {
                            prune = True
                            selfHeal = True
                        }
                        retry = {
                            backoff = {
                                duration = "10s"
                                factor = 2
                                maxDuration = "1m0s"
                            }
                            limit = 60
                        }
                        syncOptions = [
                            "CreateNamespace=True"
                            "PrunePropagationPolicy=foreground"
                            "PruneLast=True"
                        ]
                    }
                    sources = [
                        {
                            path = parameters?.argocd?.application?.source?.path
                            repoURL = parameters?.argocd?.application?.source?.repoURL
                            targetRevision = parameters?.argocd?.application?.source?.targetRevision
                            plugin = {
                                name = "envsubstappofapp"
                                env = parameters?.argocd?.application?.source?.envVars
                            }
                        }
                    ]
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scK8sProviderName
        }
    }
}

_items += [
    _calicoHelmChart
    _argocdHelmChart
    _Application
]

dxr = {
    **oxr
}
items = _items + [dxr]
