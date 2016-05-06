## Metadata for Development Statistics
The following are clarifications of the meaning some of the more esoteric terms used within the stats document that describes this project, as well as details on the data sources that were used as inputs in these analyses:

#### Group (column):
Within the group column two base types exist, properties groups of properties that have been influence by the development of the MAX lines and those, thos
* Properties in MAX walk shed
*This group consists of tax lots that are within network walking distance one or more MAX stops (network, meaning the distance traveled along streets and trails rather than as the crow flies) that have been developed since the decision to build the oldest MAX stop within walking range was made.  The network walk threshold that applies is given in the 'Walk Distance' column*
* Nine largest cities in TriMet District (not in MAX walk shed)
* TriMet District (not in MAX walk shed)
* Urban Growth Boundary (not in MAX walk shed)

Variants of the latter three groups also exist, whose names end with ‘not in MAX walk shed’


#### MAX Zone (column):
MAX zones are derived from collections of consecutive stops that are within regions that have similar characteristics such as population density, walkability, etc.  The map below displays the division of stops into MAX zones.

![max stop zone map](https://raw.githubusercontent.com/grant-humphries/dev-near-light-rail/master/static_maps/max_zones_by_stop.png)

If a tax lot meets the construction date criteria for and is within walking distance of two or more stops that are in different MAX zones, then the value of that tax lot is included in the tabulation for both zones, but double counting is eliminated in the 'All Zones' rows.  For this reason adding up each of the MAX zones for 'Properties in MAX walk shed' will give you a different and larger number than what is in 'All Zones'.  The image below display how tax lots are divided once they have been assigned a zone:

![tax lot zone map](https://raw.githubusercontent.com/grant-humphries/dev-near-light-rail/master/static_maps/comp_zones_half_mile_tm_dist.png)


Parcels summed in rows with a 'Group' of 'Properties in MAX walk shed' are tax lots that are within 'Property Value' is the market value of these tax lots (land and building value) derived from the most current version (at the time that this analysis was conducted) of RLIS tax lots data set.

'Prop Value per Acre' for 'Properties in MAX walk shed' is derived by taking 'Property Value' and dividing it by the acreage of all tax lots within walking distance of MAX stops (not just the tax lots with recent construction that comprise the dollar value in 'Property Value').  Tax lots that are at least 80% covered by regions defined as Parks, Natural Areas, Cemeteries or Golf Courses by RLIS's 'Outdoor Recreation and Conservation Areas' data set are excluded from all phases of this analysis.

To compare real estate development in areas near MAX stations to levels throughout the Portland metro region the similar statistics were compiled for three larger groups of properties: tax lots within the TriMet Service District Boundary, tax lots within the Urban Growth Boundary, and tax lots within the limits of the nine most populous cities in the TriMet district (Portland, Gresham, Hillsboro, Beaverton, Tualatin, Tigard, Lake Oswego, Oregon City, and West Linn).  To highlight construction for a similar time period as the properties summed in 'Properties in MAX walk shed' a '(MAX) decision to build year' was assigned to every tax lot in the three-county region.  This mapping was made by first determining which MAX stop was closest to each parcel and then assigning the decision to build year of that stop to the parcel (parcels were also given the 'MAX Zone' of their closest stop, so they could be broken up into sub-groups).  From there the same time-based criteria was applied to these properties as to those in station walk sheds: tax lots that have been developed in the same year or more recently than the nearest station's decision to build year were included in the 'Total Value' summation.  'Value per Acre' was then tabulated by dividing by the area of all tax lots in those regions (TriMet District, UGB, Nine Biggest Cities), excluding only the natural areas mentioned above.

#### New Multifamily Housing Units (column)
Multifamily housing units are collections of tax lots that comprise apartment complexes, condos, etc.  Values in this column are tabulated similarly to 'Property Value' field: for units to be included in the '...MAX walk shed' or comparison groups they needed to meet same criteria established for the 'Property Value' numbers.  Note however, that the 'Property Value' dollar figures are a valuation for both single family residences in addition to multi-family housing units, so the average value of a multifamily unit can *not* be derived from these two numbers.

#### Sources:
* [OpenStreetMap](osm.org) (street and trail network)
* [Oregon Metro's RLIS](http://rlisdiscovery.oregonmetro.gov/) (tax lots, multifamily housing inventory, Outdoor Recreation and Conservation Areas, Urban Growth Boundary, city limits)
* [TriMet GIS](http://developer.trimet.org/gis/) (rail stations, TriMet Service District boundary)


Note: See sheet one in this book for source information and an explanation of the statistics.  Numbers here were derived and are presented in exactly the same way as sheet one with a single key difference.  The comparison groups (TriMet District, UGB, Nine Biggest Cities) on sheet one include all tax lots (and multi-family housing units) inside the boundary that defines the region, here tax lots that are within walking distance of MAX (and thus comprise the 'Properties in MAX walk shed statistics) are excluded from the comparison groups.