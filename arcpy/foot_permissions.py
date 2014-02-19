# Settings for this network attribute:
# Name: 'foot_permissions' NOTE!!!: This attribute must have this exact name or the 'create_isocrones.py'
# script won't be able to find it
# Usage Type: Restriction
# Restriction Usage: Prohibited
def footPermissions(foot, access, highway, indoor):
	if foot in ('yes', 'designated', 'permissive'):
		return False
	elif access == 'no' or highway in ('trunk', 'motorway', 'construction') or foot == 'no' or indoor == 'yes':
		return True
	else:
		return False

footPermissions(!foot!, !access!, !highway!, !indoor!)

# Directions applied to: both

# Name: 'walk_minutes'
# Usage Type: Cost
# Units: leave as 'Unknown', see below for details
# Data Type: Double
# length is assume to be in feet and walk speed is 3 miles per hour in this case
def walkMinutes(length):
	walk_time = length / (5280 * (3 / float(60)))
	return walk_time

# created a new field and used !shape.length@feet! to calculate length in feet
walkMinutes(!Shape!)

# Directions applied to: both

# NOTE!!!! Building the network dataset may not work if you set the units for the walk length attribute
# to minutes, or if you set it at all, this seems to be a bug.  However to generate service areas using an
# arcpy script as I wish to here there must be a distance and time-based attribute and detection the type
# of a cost based attribute is based on units.  I work around that I have found is to leave the units for
# walk distance undefined in the wizard, then go back and open the network dataset properties in the
# arc catalog window and assign them there and rebuild the network

# Also the PostGIS streets and trails layer is being saved as a shape file by QGIS is currently adding 
# leading spaces in front of the attributes values, these must be removed for the functions above to work
# (use python 'field'.strip() in field calculator)