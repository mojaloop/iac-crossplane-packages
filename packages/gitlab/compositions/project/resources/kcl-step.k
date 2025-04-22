import regex

# Read the XR
oxr = option("params").oxr
ocds = option("params").ocds

get = lambda x: any, y: str, d: any -> any {
    """
            Get an item from a dictionary using a dot separated path.
            If the item is not found, return a default value.
            """
    p = regex.split(y, "\.")
    c = p[0]
    y = ".".join(p[1::])
    x[c] if len(p) == 1 and c in x else d if c not in x else get(x[c], y, d)
}

spec = oxr.spec
status = oxr.status
p = spec.parameters

_initializeWithReadme = p?.project?.initializeWithReadme
members = get(p?.project, "members", [])

_namespaceIdSelector = Undefined
if p?.project?.groupName:
    _namespaceIdSelector = {
        matchLabels = {
            "gitlab.atlantis.eon.com/group-name" = p?.project?.groupName
        }
    }

#render project
_project = {
    apiVersion = "projects.gitlab.crossplane.io/v1alpha1"
    kind = "Project"
    metadata.annotations = {"krm.kcl.dev/composition-resource-name" = "project"}
    spec = {
        forProvider = {
            name = p?.project?.name
            namespaceId = p?.project?.groupId
            namespaceIdRef = p?.project?.groupIdRef
            namespaceIdSelector = p?.project?.groupIdSelector or _namespaceIdSelector
            path = p?.project?.name
            description = p?.project?.description
            defaultBranch = p?.project?.defaultBranch
            visibility = p?.project?.visibility
            repositoryAccessLevel = p?.project?.repositoryAccessLevel
            approvalsBeforeMerge = p?.project?.approvalsBeforeMerge
            initializeWithReadme = _initializeWithReadme
            forkingAccessLevel = p?.project?.forkingAccessLevel
            issuesAccessLevel = p?.project?.issuesAccessLevel
            mergeRequestsAccessLevel = p?.project?.mergeRequestsAccessLevel
            buildsAccessLevel = p?.project?.buildsAccessLevel
            wikiAccessLevel = p?.project?.wikiAccessLevel
            snippetsAccessLevel = p?.project?.snippetsAccessLevel
            pagesAccessLevel = p?.project?.pagesAccessLevel
            operationsAccessLevel = p?.project?.operationsAccessLevel
            lfsEnabled = p?.project?.lfsEnabled
            mergeMethod = p?.project?.mergeMethod
            allowMergeOnSkippedPipeline = p?.project?.allowMergeOnSkippedPipeline
            onlyAllowMergeIfAllDiscussionsAreResolved = p?.project?.onlyAllowMergeIfAllDiscussionsAreResolved
            onlyAllowMergeIfPipelineSucceeds = p?.project?.onlyAllowMergeIfPipelineSucceeds
            onlyMirrorProtectedBranches = p?.project?.onlyMirrorProtectedBranches
            removeSourceBranchAfterMerge = p?.project?.removeSourceBranchAfterMerge
            requestAccessEnabled = p?.project?.requestAccessEnabled
            ciConfigPath = p?.project?.ciConfigPath
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}
#render members
_projectMembers = []
_projectMembers += [{
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XMember"
    metadata.annotations = {"krm.kcl.dev/composition-resource-name" = "member-{}".format(i)}
    spec = {
        managementPolicies = spec?.managementPolicies
        parameters = {
            members = members
            memberType = "project"
            scope = ocds["project"]?.Resource?.status?.atProvider?.id
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            name = spec?.providerConfigRef?.gitlabProvider
        }
    }
} if (members) else {} for i, m in members]

dxr = {
    **oxr
}

items = [dxr, _project] + _projectMembers
