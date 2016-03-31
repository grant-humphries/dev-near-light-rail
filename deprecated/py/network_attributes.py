# Settings for this network attribute:

# NAME: 'foot_permissions' NOTE!!!: This attribute must have this exact name or the python script
# that generates the isochrones won't be able to find it
# USAGE TYPE: Restriction
# RESTRICTION USAGE: Prohibited
# USE BY DEFAULT?: Yes

# EVALUATORS (click Evaluators button to access these settings): there will be two items used in
# evaluators that have all of the same values except for the 'Direction' field
# Source: 'osm_foot', Direction: item 1 - 'From-To', item 2 - 'To-From', Element: 'Edge', Type 'Field',
# Value: (function below).  Note that for this function 'True' means walking is prohibited and 'False'
# means that it's allowed
def footPermissions(foot, access, highway, indoor):
    if foot in ('yes', 'designated', 'permissive'):
        return False
    # note that during the building of osm_foot shapefile all ways that were tagged highway=construction
    # and that had a valid street type value in the construction tag had that value transferred to the
    # highway field.  this is because we want to route along streets that are under construction in this
    # analysis unless there finished type isn't specified (in which case the 'construction' value would
    # persist in the highway field)
    elif access == 'no' or highway in ('trunk', 'motorway', 'construction') or foot == 'no' or indoor == 'yes':
        return True
    else:
        return False

footPermissions(!foot!, !access!, !highway!, !indoor!)


# UPDATE 02/2014 - ***I refactored that generates the isocrones so adding the walk minutes attribute is
# no longer compulsory.***  I'm leaving the code in place in case walk minutes are ever needed.

# NAME: 'walk_minutes'
# USAGE TYPE: Cost
# UNITS: leave as 'Unknown', see below for details
# DATA TYPE: Double
# USE BY DEFAULT?: No

# EVALUATORS:
# Direction: item 1 - 'From-To', item 2 - 'To-From', Element: 'Edge', Type 'Field', Value: (function below)

# length is assumed to be in feet and walk speed is 3 miles per hour in this case
def walkMinutes(length):
    walk_time = length / (5280 * (3 / float(60)))
    return walk_time

walkMinutes(!Shape!)