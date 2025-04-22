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
#render members
_items = []
_Group = {
    apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    kind = "Group"
    metadata.annotations: {"krm.kcl.dev/composition-resource-name" = "group"}
    spec = {
        forProvider = {
            name = p?.group.name
            description = p?.group.description
            parentId = p?.group.parentId
            parentIdSelector = {
                matchLabels = {
                    "gitlab.mojaloop.io/group-name" = p?.group.parentGroupName
                }
            }
            emailsDisabled = p?.group.emailsDisabled
            path = p?.group.name
            visibility = p?.group.visibility
            projectCreationLevel = p?.group.projectCreationLevel
            subgroupCreationLevel = p?.group.subgroupCreationLevel
            lfsEnabled = p?.group.lfsEnabled
        }
        managementPolicies = spec.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
    }
}

members = get(p.group, "members", [])
_Memberships = []

_Memberships += [{
    apiVersion = "gitlab.mojaloop.io/v1alpha1"
    kind = "XMember"
    metadata.annotations: {"krm.kcl.dev/composition-resource-name" = "member-{}".format(i)}
    spec = {
        managementPolicies: spec?.managementPolicies
        parameters = {
            members = members
            memberType = "group"
            scope = ocds["group"]?.Resource?.status?.atProvider?.id
        }
        managementPolicies = spec.managementPolicies
        providerConfigsRef = {
            gitlabProvider = spec?.providerConfigsRef?.gitlabProvider
        }
    }
} if (members) else {} for i, m in members]

_items += [_Group] + _Memberships
dxr = {**oxr}
items = _items + [dxr]
