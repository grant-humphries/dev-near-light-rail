## Metadata for Development Statistics
The following are explanations of the terms used within the statistics that describes real estate development around light rail (MAX) lines, as well as details on the data sources that were used as inputs in the analysis:

#### Group (column):
Within the Group column two base types exist: properties that are hypothesized to have been influenced by the development of the MAX lines, and a set of comparison groups that were not influenced or less influenced by that light rail construction:
* **'Properties in MAX walk shed'**  
This group consists of tax lots that are within network walking distance of one or more MAX stops and that have been developed since the decision to build the oldest MAX stop within the defined walking range was made.  The network walk threshold that applies is given in the 'Walk Distance' column and development year threshold(s) in 'MAX Year'.  Because of these properties' location and development date they are assumed to have been influenced by the creation of the MAX lines
* **Comparison groups**  
To compare real estate development rates in areas near MAX stations to levels throughout the Portland metro region statistics were compiled for three larger groups of properties: tax lots within the TriMet District Service District Boundary (labeled: 'TriMet District'), tax lots within the 'Urban Growth Boundary', and tax lots within the limits of the nine most populous cities in the TriMet district: Portland, Gresham, Hillsboro, Beaverton, Tualatin, Tigard, Lake Oswego, Oregon City, and West Linn (labeled: 'Nine largest cities in TriMet District').  To attain construction only for time periods comparable to properties summed in the MAX walk shed group a minimum development year is assigned to every tax lot in a comparison group.  This assignment is made by finding the closest MAX stop to each parcel and using the decision to build year of that stop.  The same time-based criteria is applied to these properties as to those in station walk sheds: tax lots that have been developed in the same year or more recently than the nearest station's decision to build year are included in the 'Market Property Value' summation.  Because the three comparison groups contain all of the properties in the stop walk sheds a variant of each exists that excludes those walk shed properties.  The aim here is to have a set of comparison groups that are completely separate from the study group.  These variants are present in the second sheet of the excel workbook and are appended with: 'not in MAX walk shed'.

#### MAX Zone (column):
MAX zones are derived from collections of consecutive stops that are within regions that have similar characteristics such as population density and walkability.  The map below displays the division of stops into MAX zones:

![max stop zone map](https://raw.githubusercontent.com/grant-humphries/dev-near-light-rail/master/static_maps/max_zones_by_stop.png)

If a tax lot meets the construction date criteria for and is within walking distance of two or more stops that are in different MAX zones, then the value of that tax lot is included in the tabulation for both zones, but there is no double counting in the 'All Zones' statistics.  For this reason adding up each of the MAX zones for walk shed properties will give you a different and larger number than what is in 'All Zones'.  Parcels that are only in the comparison groups are given the MAX zone of their closest stop.  The image below displays tax lots divided into these zones:

![tax lot zone map](https://raw.githubusercontent.com/grant-humphries/dev-near-light-rail/master/static_maps/comp_zones_half_mile_tm_dist.png)

#### MAX Year (column)
Decision to build year of stops within a 'MAX Zone'.  Properties must have been developed since the year of their nearby stops to be eligible to be counted in the market value and housing unit totals.

#### Walk Distance (column)
Network walk distance that defines a stop walk shed.  'Network' means the distance traveled along streets and trails rather than as the crow flies.  Values in this field are given in feet.  This attribute does not apply to comparison properties.

#### New Multifamily Housing Units (column)
Multifamily housing units are collections of tax lots that comprise apartment complexes, condos, etc.  Note that the 'Market Property Value' dollar figures are a valuation for both single family residences in addition to multifamily housing units, so the average value of a multifamily unit can *not* be derived from these two numbers.

#### Acres (column)
Acres contains the acreage for all properties in the supplied 'Group' and 'MAX Zone', *not* just those that meet the criteria of being developed since a nearby MAX line.  The only tax lots that are excluded from this count are those that are at least 80% covered by regions defined as Parks, Natural Areas, Cemeteries or Golf Courses by RLIS 'Outdoor Recreation and Conservation Areas' data set, those types of properties are extracted from all phases of this analysis.

#### Sources:
* [OpenStreetMap](osm.org) (street and trail network)
* [RLIS](http://rlisdiscovery.oregonmetro.gov/) (city limits, tax lots, Multifamily Housing Inventory, Outdoor Recreation and Conservation Areas, Urban Growth Boundary, )
* [TriMet](http://developer.trimet.org/gis/) (rail stations, TriMet Service District boundary)
