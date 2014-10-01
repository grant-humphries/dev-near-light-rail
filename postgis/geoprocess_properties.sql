--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--***Taxlots***

--------------------------
--CREATE ANALYSIS TAXLOTS
drop table if exists analysis_taxlots cascade;
create table analysis_taxlots (
	id serial primary key,
	gid int references taxlots, 
	geom geometry,
	tlid text,
	totalval numeric,
	gis_acres numeric,
	prop_code text,
	landuse text,
	yearbuilt int,
	max_year int,
	max_zone text,
	near_max boolean,
	walk_dist numeric,
	ugb boolean,
	tm_dist boolean,
	nine_cities boolean
);

--Spatially join the tax lots and isochrones (the former of which indicates areas that are within a given
--walking distance of max stops).  The output is tax lots joined to attribute information of the isochrones
--that they intersect.  Note that there are intentionally duplicates in this table if a taxlot is within
--walking distance multiple stops that are in different 'MAX Zones', but duplicates of a properties within
--the same MAX Zone are eliminated
insert into analysis_taxlots (gid, geom, tlid, totalval, gis_acres, prop_code, landuse,
		yearbuilt, max_year, max_zone, near_max, walk_dist)
	select tno.gid, tno.geom, tno.tlid, tno.totalval, tno.gis_acres, tno.prop_code, tno.landuse,
		tno.yearbuilt, min(iso.incpt_year), iso.max_zone, true, iso.walk_dist
	from taxlots_no_orca tno, isochrones iso
		where ST_Intersects(tno.geom, iso.geom)
	group by tno.gid, tno.geom, tno.tlid, tno.totalval, tno.gis_acres, tno.prop_code, 
		tno.landuse, tno.yearbuilt, iso.max_zone, iso.walk_dist;

--Get the gid's of the taxlots that are within walking distance of max stops
drop table if exists max_taxlots cascade;
create table max_taxlots with oids as
	select gid
	from analysis_taxlots;

--Find the max zone and max year of the nearest stop to each tax lot and put them in a table,
--this uses the '<->' postgis nearest neighbor operator, discuss of this can be found here:
--http://gis.stackexchange.com/questions/52792/calculate-min-distance-between-points-in-postgis
drop table if exists tl_nearest_stop cascade;
create table tl_nearest_stop with oids as
	select gid,
		--a subquery in the select clause can only return one value, but two are needed
		--from the stops table so they're being put into an array to meet the single
		--output condition
		(select array[incpt_year::text, max_zone] 
		from max_stops order by geom <-> tno.geom limit 1) as year_zone
	from taxlots_no_orca tno;

drop index if exists mx_taxlots_gid_ix cascade;
create index mx_taxlots_gid_ix on max_taxlots using BTREE (gid);

drop index if exists tl_near_stop_gid_ix cascade;
create index tl_near_stop_gid_ix on tl_nearest_stop using BTREE (gid);

--clean up after inserts and table creation
vacuum analyze;

--Insert taxlots that are not within walking distance of max stops into analysis_taxlots 
insert into analysis_taxlots (gid, geom, tlid, totalval, gis_acres, prop_code,
		landuse, yearbuilt, max_year, max_zone, near_max)
	select tno.gid, tno.geom, tno.tlid, tno.totalval, tno.gis_acres, tno.prop_code,
		tno.landuse, tno.yearbuilt, tns.year_zone[1]::int, tns.year_zone[2], false
	from taxlots_no_orca tno, tl_nearest_stop tns
	where tno.gid = tns.gid
		and not exists (select null from max_taxlots where gid = tno.gid);

--Temp table will turn the 9 most populous cities in the TM district into a single geometry
drop table if exists nine_cities cascade;
create table nine_cities with oids as
	select ST_Union(geom) as geom
	from (select city.gid, city.geom, 1 as collapser
		from city
		where cityname in ('Portland', 'Gresham', 'Hillsboro', 'Beaverton', 
			'Tualatin', 'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')) as collapsable_city
	group by collapser;

--Add indices to improve performance on upcoming spatial comparisons
drop index if exists n_city_gix cascade;
create index n_city_gix on nine_cities using GIST (geom);

drop index if exists a_taxlot_gix cascade;
create index a_taxlot_gix on analysis_taxlots using GIST (geom);

cluster analysis_taxlots using a_taxlot_gix;
vacuum analyze;

--Determine if each of the analysis taxlots is in the trimet district, urban growth boundary, 
--and city limits of the nine biggest cities in the Portland metro area (Oregon only)
update analysis_taxlots as atx set
	--Returns True if a taxlot intersects the urban growth boundary
	ugb = (select ST_Intersects(ugb.geom, atx.geom)
		from ugb),
	--Returns True if a taxlot intersects the TriMet's service district boundary
	tm_dist = (select ST_Intersects(td.geom, atx.geom)
		from tm_district td),
	--Returns True if a taxlot intersects one of the nine most populous cities in the TM dist
	nine_cities = (select ST_Intersects(nc.geom, atx.geom)
		from nine_cities nc);


-----------------------------------------------------------------------------------------------------------------
--***Multi-Family Housing Units***
--Works off the same framework as what is used for tax lots above.  Note that the natural areas
--don't need to be used as a filter in the way that they were with tax lots as we already know
--the type of property each of these are

--------------------------
--CREATE ANALYSIS MULTIFAM
--Divisors for overall area comparisons will still come from analysis_taxlots, but numerators
--will come from the table below.  This because the multi-family layer doesn't have full coverage
--of all buildable land in the region the way the tax lot data does
drop table if exists analysis_multifam cascade;
create table analysis_multifam (
	id serial primary key,
	gid int references multifamily, 
	geom geometry,
	metro_id int,
	units int,
	unit_type text,
	gis_acres numeric,
	mixed_use int,
	yearbuilt int,
	max_year int,
	max_zone text,
	near_max boolean,
	walk_dist numeric,
	ugb boolean,
	tm_dist boolean,
	nine_cities boolean
);

insert into analysis_multifam (gid, geom, metro_id, units, unit_type, gis_acres, mixed_use, 
		yearbuilt, max_year, max_zone, near_max, walk_dist)
	--the area value for multifamily housing given in square feet in a field called 'area',
	--this is converted to acres (43,560 sqft in 1 acre) and stored in 'gis_acres' to be
	--consistent with the design of the taxlot tables
	select mf.gid, mf.geom, mf.metro_id, mf.units, mf.unit_type, (mf.area / 43560), mf.mixed_use,
		mf.yearbuilt, min(iso.incpt_year), iso.max_zone, true, iso.walk_dist
	from multifamily mf, isochrones iso
		where ST_Intersects(mf.geom, iso.geom)
	group by mf.gid, mf.geom, mf.metro_id, mf.units, mf.yearbuilt, mf.unit_type, mf.area, 
		mf.mixed_use, iso.max_zone, iso.walk_dist;

--Get the gid's of the taxlots that are within walking distance of max stops
drop table if exists max_multifam cascade;
create table max_multifam with oids as
	select gid
	from analysis_multifam;

--Find the max zone and max year of the nearest stop to each tax lot and put them in a table,
--this uses the '<->' postgis nearest neighbor operator, discuss of this can be found here:
--http://gis.stackexchange.com/questions/52792/calculate-min-distance-between-points-in-postgis
drop table if exists mf_nearest_stop cascade;
create table mf_nearest_stop with oids as
	select gid,
		--a subquery in the select clause can only return one value, but I need two
		--from the stops table so I'm putting them into an array
		(select array[incpt_year::text, max_zone] 
		from max_stops order by geom <-> mf.geom limit 1) as year_zone
	from multifamily mf;

vacuum analyze;

--Insert multifam units outside of walking distance into the analysis-multifam
insert into analysis_multifam (gid, geom, metro_id, units, unit_type, gis_acres,
		mixed_use, yearbuilt, max_year, max_zone, near_max)
	select mf.gid, mf.geom, mf.metro_id, mf.units, mf.unit_type, (mf.area / 43560),
		mf.mixed_use, mf.yearbuilt, mns.year_zone[1]::int, mns.year_zone[2], false
	from multifamily mf, mf_nearest_stop mns
	where mf.gid = mns.gid
		and not exists (select null from max_multifam where gid = mf.gid);

--Should improve performance on upcoming spatial comparisons
drop index if exists a_multifam_gix cascade;
create index a_multifam_gix on analysis_multifam using GIST (geom);

cluster analysis_multifam using a_multifam_gix;
vacuum analyze;

update analysis_multifam as amf set
	ugb = (select ST_Intersects(ugb.geom, amf.geom)
		from ugb),

	tm_dist = (select ST_Intersects(td.geom, amf.geom)
		from tm_district td),

	nine_cities = (select ST_Intersects(nc.geom, amf.geom)
		from nine_cities nc);

--ran in ~4,702,524 ms on 5/20/14 (definitely benefitted from some caching though)