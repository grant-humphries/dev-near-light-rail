# Settings for this network attribute:

# NAME: 'foot_permissions' NOTE!!!: This attribute must have this exact name or the python script
# that generates the isoscrones won't be able to find it
# USAGE TYPE: Restriction
# RESTRICTION USAGE: Prohibited
# USE BY DEFAULT?: Yes

# Note that for this function 'True' means walking is prohibited and 'False' means that it's allowed
def footPermissions(foot, access, highway, indoor):
	if foot in ('yes', 'designated', 'permissive'):
		return False
	elif access == 'no' or highway in ('trunk', 'motorway', 'construction') or foot == 'no' or indoor == 'yes':
		return True
	else:
		return False

footPermissions(!foot!, !access!, !highway!, !indoor!)

# DIRECTION: both

# UPDATE 02/2014 - ***I refactored that generates the isocrones so adding the walk minutes attribute is
# no longer compulsory.***  I'm leaving the code in place in case walk minutes are ever needed.

# NAME: 'walk_minutes'
# USAGE TYPE: Cost
# UNITS: leave as 'Unknown', see below for details
# DATA TYPE: Double
# USE BY DEFAULT?: No

# length is assumed to be in feet and walk speed is 3 miles per hour in this case
def walkMinutes(length):
	walk_time = length / (5280 * (3 / float(60)))
	return walk_time

walkMinutes(!Shape!)

# DIRECTION: both

# NOTE: Building the network dataset may not work if you set the units for the walk length attribute
# to minutes, or if you set it at all, this seems to be a bug.  I work around that I have found is to 
# leave the units for walk distance undefined in the wizard, then go back and open the network dataset
# properties in the arc catalog window and assign them there and rebuild the network

# UPDATE 02/2014: leading spaces were not present on this iteration
# Also the PostGIS streets and trails layer is being saved as a shape file by QGIS is currently adding 
# leading spaces in front of the attributes values, these must be removed for the functions above to work
# (use python 'field'.strip() in field calculator)
