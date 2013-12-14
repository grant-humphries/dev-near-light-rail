# Setting for this network attribute:
# Usage Type: Restriction
# Restriction Usage: Prohibited
def footPermissions(foot, access, highway):
	if foot in ('yes', 'designated', 'permissive'):
		return False
	elif access == 'no' or highway in ('trunk', 'motorway', 'construction') or foot == 'no':
		return True
	else:
		return False

footPermissions(!foot!, !access!, !highway!)

# length is assume to be in feet and walk speed is 3 miles per hour in this case
def walkMinutes(length):
	walk_time = length / (5280 * (3 / float(60)))
	return walk_time

# created a new field and used !shape.length@feet! to calculate length in feet
walkMinutes(!Shape!)

# NOTE!!!! Building the network dataset may not work if you set the units for the walk length attribute
# to minutes, or if you set it at all, this seems to be a bug

# Also the PostGIS streets and trails layer is being saved as a shape file by QGIS is currently adding 
# leading spaces in front of the attributes values, these must be removed for the functions above to work
# (use python 'field'.strip() in field calculator)