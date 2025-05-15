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
                name = "calico"
                repository = "https://raw.githubusercontent.com/projectcalico/calico/v3.30.1/charts/tigera-operator"
                version = parameters?.calico?.chartVersion
            }
            namespace = "calico"
        }
    }
}

# ArgoCD Helm Chart install
_argocdHelmChart = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "{}-argocd".format(oxr.metadata.name)
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
            values = {
                fullnameOverride = "argocd"
                configs = {
                    cm = {
                        "exec.enabled" = "true"
                        "kustomize.buildOptions" = "--enable-helm --helm-kube-version 1.29-0 --load-restrictor LoadRestrictionsNone"
                        "application.resourceTrackingMethod" = "annotation"
                    }
                    params = {
                        "server.insecure" = True
                        "server.enable.proxy.extension" = "true"
                        "controller.diff.server.side" = "true"
                    }
                    cmp = {
                        create = True
                        plugins = {
                            envsubstappofapp = {
                                init = {
                                    command = ["sh", "-c"]
                                    args = ["kustomize build . --load-restrictor LoadRestrictionsNone -o raw-kustomization.yaml"]
                                }
                                generate = {
                                    command = ["sh", "-c"]
                                    args = ["envsubst < raw-kustomization.yaml > processed-kustomization.yaml && cp processed-kustomization.yaml /dev/stdout"]
                                }
                                discover = {
                                    fileName = "kustomization.*"
                                }
                            }
                            envsubst = {
                                discover = {
                                    fileName = "kustomization.*"
                                }
                                generate = {
                                    command = ["sh", "-c"]
                                    args = ["for f in *.yaml ; do cat $f | envsubst > $f.sub && mv $f.sub $f ; done && kustomize build . --enable-helm --helm-kube-version 1.29-0 --load-restrictor LoadRestrictionsNone > /dev/stdout"]
                                }
                            }
                        }
                    }
                }
                repoServer = {
                    env = [
                        {name = "HELM_CACHE_HOME", value = "/helm-working-dir"}
                        {name = "HELM_CONFIG_HOME", value = "/helm-working-dir"}
                        {name = "HELM_DATA_HOME", value = "/helm-working-dir"}
                    ]
                    volumes = [
                        {name = "custom-tools", emptyDir = {}}
                        {name = "cmp-plugin", configMap = {name = "argocd-cmp-cm"}}
                    ]
                    initContainers = [
                        {
                            name = "download-tools"
                            image = "golang:1.22.4-alpine3.20"
                            command = ["sh", "-c"]
                            args = ["apk add git && go install github.com/drone/envsubst/cmd/envsubst@v1.0.3 && mv $GOPATH/bin/envsubst /custom-tools/ && wget https://gist.githubusercontent.com/enriched/11c7d81aa271b258f835620b1aca2e55/raw/2017a4202da30506b1fedc2981afed41e259fe77/in-pod-kubeconfig.sh && chmod +x in-pod-kubeconfig.sh && mv in-pod-kubeconfig.sh /custom-tools/"]
                            volumeMounts = [
                                {mountPath = "/custom-tools", name = "custom-tools"}
                            ]
                        }
                    ]
                    extraContainers = [
                        {
                            name = "debug-tools"
                            image = "quay.io/argoproj/argocd"
                            command = ["sh", "-c"]
                            args = ["while true; do echo \"running\"; sleep 300; done"]
                            volumeMounts = [
                                {mountPath = "/var/run/argocd", name = "var-files"}
                                {mountPath = "/home/argocd/cmp-server/plugins", name = "plugins"}
                                {mountPath = "/tmp", name = "tmp"}
                                {name = "custom-tools", subPath = "envsubst", mountPath = "/usr/local/bin/envsubst"}
                                {name = "custom-tools", subPath = "in-pod-kubeconfig.sh", mountPath = "/usr/local/bin/in-pod-kubeconfig.sh"}
                                {name = "helm-working-dir", mountPath = "/helm-working-dir"}
                            ]
                        }
                        {
                            name = "envsubstappofapp"
                            command = ["/var/run/argocd/argocd-cmp-server"]
                            image = "quay.io/argoproj/argocd"
                            args = ["--loglevel", "debug"]
                            securityContext = {
                                runAsNonRoot = True
                                runAsUser = 999
                            }
                            volumeMounts = [
                                {mountPath = "/var/run/argocd", name = "var-files"}
                                {mountPath = "/home/argocd/cmp-server/plugins", name = "plugins"}
                                {mountPath = "/tmp", name = "tmp"}
                                {mountPath = "/home/argocd/cmp-server/config/plugin.yaml", subPath = "envsubstappofapp.yaml", name = "cmp-plugin"}
                                {name = "custom-tools", subPath = "envsubst", mountPath = "/usr/local/bin/envsubst"}
                            ]
                        }
                        {
                            name = "envsubst"
                            command = ["/var/run/argocd/argocd-cmp-server"]
                            image = "quay.io/argoproj/argocd"
                            args = ["--loglevel", "debug"]
                            securityContext = {
                                runAsNonRoot = True
                                runAsUser = 999
                            }
                            volumeMounts = [
                                {mountPath = "/var/run/argocd", name = "var-files"}
                                {mountPath = "/home/argocd/cmp-server/plugins", name = "plugins"}
                                {mountPath = "/tmp", name = "tmp"}
                                {mountPath = "/home/argocd/cmp-server/config/plugin.yaml", subPath = "envsubst.yaml", name = "cmp-plugin"}
                                {name = "custom-tools", subPath = "envsubst", mountPath = "/usr/local/bin/envsubst"}
                            ]
                        }
                    ]
                }
            }
            wait = True
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
    _argocdHelmChart
    _Application
]

dxr = {
    **oxr
}
items = _items + [dxr]
