# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters

# Method to check if the resource is ready
ready = lambda o: any, statusPath = "atProvider" -> bool {
    status = o?.Resource?.status
    objstatus = status?.conditions or []
    len(objstatus) > 0 and all_true([c.status == "True" for c in objstatus]) and status and statusPath in status
}

# Method to check if daemonset is ready
daemonsetReady = lambda o: any -> bool {
    status = o?.Resource?.status?.atProvider?.manifest?.status
    if not status:
        False
    # Check if desiredNumberScheduled is same as numberAvailable
    status?.desiredNumberScheduled == status?.numberAvailable and (status?.numberAvailable or 0) > 0
}

print(ocds["daemon-set"]?.Resource?.status?.atProvider?.manifest?.status?.desiredNumberScheduled)
print(ocds["daemon-set"]?.Resource?.status?.atProvider?.manifest?.status?.numberAvailable)


# Initialize the items list
_items = []
## Adding resources
#Weave CNI Install
_serviceAccount = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-sa".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "service-account"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "v1"
                kind = "ServiceAccount"
                metadata = {
                    name = "weave-net"
                    labels = {
                        name = "weave-net"
                    }
                    namespace = "kube-system"
                }
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scK8sProviderName
        }
    }
}

_clusterRole = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-cr".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "cluster-role"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "rbac.authorization.k8s.io/v1"
                kind = "ClusterRole"
                metadata = {
                    name = "weave-net"
                    labels = {
                        name = "weave-net"
                    }
                }
                rules = [
                    {
                        apiGroups = [""]
                        resources = ["pods", "namespaces", "nodes"]
                        verbs = ["get", "list", "watch"]
                    }
                    {
                        apiGroups = ["extensions"]
                        resources = ["networkpolicies"]
                        verbs = ["get", "list", "watch"]
                    }
                    {
                        apiGroups = ["networking.k8s.io"]
                        resources = ["networkpolicies"]
                        verbs = ["get", "list", "watch"]
                    }
                    {
                        apiGroups = [""]
                        resources = ["nodes/status"]
                        verbs = ["patch", "update"]
                    }
                ]
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec.providerConfigsRef.scK8sProviderName
        }
    }
}

_clusterRoleBinding = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-crb".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "cluster-role-binding"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "rbac.authorization.k8s.io/v1"
                kind = "ClusterRoleBinding"
                metadata = {
                    name = "weave-net"
                    labels = {
                        name = "weave-net"
                    }
                }
                roleRef = {
                    kind = "ClusterRole"
                    name = "weave-net"
                    apiGroup = "rbac.authorization.k8s.io"
                }
                subjects = [
                    {
                        kind = "ServiceAccount"
                        name = "weave-net"
                        namespace = "kube-system"
                    }
                ]
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scK8sProviderName
        }
    }
}

_role = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-role".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "role"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "rbac.authorization.k8s.io/v1"
                kind = "Role"
                metadata = {
                    name = "weave-net"
                    namespace = "kube-system"
                    labels = {
                        name = "weave-net"
                    }
                }
                rules = [
                    {
                        apiGroups = [""]
                        resources = ["configmaps"]
                        resourceNames = ["weave-net"]
                        verbs = ["get", "update"]
                    }
                    {
                        apiGroups = [""]
                        resources = ["configmaps"]
                        verbs = ["create"]
                    }
                ]
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scK8sProviderName
        }
    }
}

_roleBinding = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-rb".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "role-binding"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "rbac.authorization.k8s.io/v1"
                kind = "RoleBinding"
                metadata = {
                    name = "weave-net"
                    namespace = "kube-system"
                    labels = {
                        name = "weave-net"
                    }
                }
                roleRef = {
                    kind = "Role"
                    name = "weave-net"
                    apiGroup = "rbac.authorization.k8s.io"
                }
                subjects = [
                    {
                        kind = "ServiceAccount"
                        name = "weave-net"
                        namespace = "kube-system"
                    }
                ]
            }
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scK8sProviderName
        }
    }
}

_daemonSet = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
        name = "{}-ds".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "daemon-set"
        }
    }
    spec = {
        forProvider = {
            manifest = {
                apiVersion = "apps/v1"
                kind = "DaemonSet"
                metadata = {
                    name = "weave-net"
                    labels = {
                        name = "weave-net"
                    }
                    namespace = "kube-system"
                }
                spec = {
                    selector = {
                        matchLabels = {
                            name = "weave-net"
                        }
                    }
                    minReadySeconds = 5
                    template = {
                        metadata = {
                            labels = {
                                name = "weave-net"
                            }
                        }
                        spec = {
                            initContainers = [
                                {
                                    name = "weave-init"
                                    image = "weaveworks/weave-kube:latest"
                                    imagePullPolicy = "Always"
                                    command = ["/home/weave/init.sh"]
                                    securityContext = {
                                        privileged = True
                                    }
                                    volumeMounts = [
                                        {name = "cni-bin", mountPath = "/host/opt"}
                                        {name = "cni-bin2", mountPath = "/host/home"}
                                        {name = "cni-conf", mountPath = "/host/etc"}
                                        {name = "lib-modules", mountPath = "/lib/modules"}
                                        {name = "xtables-lock", mountPath = "/run/xtables.lock", readOnly = False}
                                    ]
                                }
                            ]
                            containers = [
                                {
                                    name = "weave"
                                    command = ["/home/weave/launch.sh"]
                                    env = [
                                        {name = "INIT_CONTAINER", value = "True"}
                                        {
                                            name = "HOSTNAME"
                                            valueFrom = {
                                                fieldRef = {
                                                    apiVersion = "v1"
                                                    fieldPath = "spec.nodeName"
                                                }
                                            }
                                        }
                                    ]
                                    image = "weaveworks/weave-kube:latest"
                                    imagePullPolicy = "Always"
                                    readinessProbe = {
                                        httpGet = {
                                            host = "127.0.0.1"
                                            path = "/status"
                                            port = 6784
                                        }
                                    }
                                    resources = {
                                        requests = {
                                            cpu = "50m"
                                        }
                                    }
                                    securityContext = {
                                        privileged = True
                                    }
                                    volumeMounts = [
                                        {name = "weavedb", mountPath = "/weavedb"}
                                        {name = "dbus", mountPath = "/host/var/lib/dbus", readOnly = True}
                                        {name = "cni-machine-id", mountPath = "/host/etc/machine-id", readOnly = True}
                                        {name = "xtables-lock", mountPath = "/run/xtables.lock", readOnly = False}
                                    ]
                                }
                                {
                                    name = "weave-npc"
                                    env = [
                                        {
                                            name = "HOSTNAME"
                                            valueFrom = {
                                                fieldRef = {
                                                    apiVersion = "v1"
                                                    fieldPath = "spec.nodeName"
                                                }
                                            }
                                        }
                                    ]
                                    image = "weaveworks/weave-npc:latest"
                                    imagePullPolicy = "Always"
                                    resources = {
                                        requests = {
                                            cpu = "50m"
                                        }
                                    }
                                    securityContext = {
                                        privileged = True
                                    }
                                    volumeMounts = [
                                        {name = "xtables-lock", mountPath = "/run/xtables.lock", readOnly = False}
                                    ]
                                }
                            ]
                            hostNetwork = True
                            dnsPolicy = "ClusterFirstWithHostNet"
                            hostPID = False
                            restartPolicy = "Always"
                            securityContext = {
                                seLinuxOptions = {}
                            }
                            serviceAccountName = "weave-net"
                            tolerations = [
                                {effect = "NoSchedule", operator = "Exists"}
                                {effect = "NoExecute", operator = "Exists"}
                            ]
                            volumes = [
                                {name = "weavedb", hostPath = {path = "/var/lib/weave"}}
                                {name = "cni-bin", hostPath = {path = "/opt"}}
                                {name = "cni-bin2", hostPath = {path = "/home"}}
                                {name = "cni-conf", hostPath = {path = "/etc"}}
                                {name = "cni-machine-id", hostPath = {path = "/etc/machine-id"}}
                                {name = "dbus", hostPath = {path = "/var/lib/dbus"}}
                                {name = "lib-modules", hostPath = {path = "/lib/modules"}}
                                {name = "xtables-lock", hostPath = {path = "/run/xtables.lock", type = "FileOrCreate"}}
                            ]
                            priorityClassName = "system-node-critical"
                        }
                    }
                    updateStrategy = {
                        type = "RollingUpdate"
                    }
                }
            }
        }
        watch = True
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scK8sProviderName
        }
    }
}

# ArgoCD Helm Chart install
_argocdHelmChart = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind = "Release"
    metadata = {
        name = "wordpress-example"
    }
    spec = {
        forProvider = {
            chart = {
                name = "argo-cd"
                repository = "https://argoproj.github.io/argo-helm"
                version = parameters?.argocd?.application?.chartVersion
            }
            namespace = "argocd"
            values = {}
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.scHelmProviderName
        }
    }
}

# ArgoCD Root application install
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
    _serviceAccount
    _clusterRole
    _clusterRoleBinding
    _role
    _roleBinding
    _daemonSet
]

# # Install ArgoCD only if the DaemonSet is ready
if daemonsetReady(ocds["daemon-set"]):
    _items += [_argocdHelmChart, _Application]

dxr = {
    **oxr
}
items = _items + [dxr]
