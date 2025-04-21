# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []
## Adding resources
_Project = {}


_items += [_Project]
dxr = {
    **oxr
}
items = _items + [dxr]
