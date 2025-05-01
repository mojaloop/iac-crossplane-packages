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
p = spec.parameters
members = get(p, "members", [])
mType = p.memberType
sScope = str(p.scope)
#render members
_items = []
_items += [{
    if mType == "group":
        apiVersion = "groups.gitlab.crossplane.io/v1alpha1"
    elif mType == "project":
        apiVersion = "projects.gitlab.crossplane.io/v1alpha1"
    kind = "Member"
    metadata = {
        if m.gitlabUserID:
            name = "{}-{}".format(m.gitlabUserID, sScope)
        elif m.gitlabUserName:
            name = "{}-{}".format(m.gitlabUserName, sScope)
    }
    spec = {
        managementPolicies: spec?.managementPolicies
        providerConfigRef = {
            name = spec?.providerConfigsRef?.gitlabProvider
        }
        forProvider = {
            accessLevel = m.role
            if mType == "group":
                groupId = p.scope
            if mType == "project":
                projectId = p.scope
            if m.gitlabUserID:
                userID = m.gitlabUserID
            elif m.gitlabUserName:
                userName = m.gitlabUserName
        }
    }
} for i, m in members]

dxr = {
    **oxr
}
items = _items + [dxr]
