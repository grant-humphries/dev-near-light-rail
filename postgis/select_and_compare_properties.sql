--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--Taxlots

--Since parks and water bodies have been 'erased' for taxlots in previous steps the attribute that
--ships with RLIS and contains the area of the feature is no longer valid and the area will be
--recalculated below
alter table trimmed_taxlots drop column if exists habitable_acres cascade;
alter table trimmed_taxlots add habitable_acres numeric;

--Since this data set is in the State Plane projection the output of the ST_Area tool will be in 
--square feet, I want acres and thus will divide that number by 43,560 as that's how many square 
--feet are in an acre
update trimmed_taxlots set habitable_acres = (ST_Area(geom) / 43560);

--Spatially join taxlots and the isochrones that were created by based places that can be reached
--within a given walking distance from MAX stops.  The output is taxlots joined to attribute information
--of the isochrones that they intersect.  Note that there are intentionally duplicates in this table if 
--a taxlot is within walking distance multiple stops that are in different 'MAX Zones'
drop table if exists max_taxlots cascade;
create table max_taxlots with oids as
	select ttl.gid, ttl.geom, ttl.tlid, ttl.totalval, ttl.habitable_acres, ttl.prop_code, ttl.landuse,
		tl.yearbuilt, min(iso.incpt_year) as max_year, iso.max_zone, iso.walk_dist
	from trimmed_taxlots ttl
		join isochrones iso
		--This command joins two features only if they intersect
		on ST_Intersects(ttl.geom, iso.geom)
	group by ttl.gid, ttl.geom, ttl.tlid, ttl.totalval, ttl.habitable_acres, ttl.prop_code, ttl.landuse,
		ttl.yearbuilt, iso.max_zone, iso.walk_dist;

--A comparison will be done later on the gid from this table and gid in comparison_taxlots.
--This index will speed that computation
drop index if exists tl_in_isos_gid_ix cascade;
create index tl_in_isos_gid_ix on max_taxlots using BTREE (gid);

--Temp table will turn the 9 most populous cities in the TM district into a single geometry
drop table if exists nine_cities cascade;
create temp table nine_cities as
	select ST_Union(geom) as geom
	from (select city.gid, city.geom, 1 as collapser
 		from city
 		where cityname in ('Portland', 'Gresham', 'Hillsboro', 'Beaverton', 
 			'Tualatin', 'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')) as collapsable_city
	group by collapser;

drop table if exists comparison_taxlots cascade;
create table comparison_taxlots with oids as
	select ttl.gid, ttl.geom, ttl.tlid, ttl.totalval, ttl.yearbuilt, ttl.habitable_acres, 
		ttl.prop_code, ttl.landuse, 
		--Finds nearest neighbor in the max stops data set for each taxlot and returns the stop's 
		--corresponding 'MAX Zone'
		--Derived from (http://gis.stackexchange.com/questions/52792/calculate-min-distance-between-points-in-postgis)
		(select mxs.max_zone
			from max_stops mxs 
			order by ttl.geom <-> mxs.geom 
			limit 1) as max_zone,
		--Returns True if a taxlot intersects the urban growth boundary
		(select ST_Intersects(ugb.geom, ttl.geom)
			from ugb) as ugb,
		--Returns True if a taxlot intersects the TriMet's service district boundary
		(select ST_Intersects(tm.geom, ttl.geom)
			from tm_district tm) as tm_dist,
		--Returns True if a taxlot intersects one of the nine most populous cities in the TM dist
		(select ST_Intersects(nc.geom, ttl.geom)
			from nine_cities nc) as nine_cities
	from trimmed_taxlots ttl;

--A comparison will be done later on the gid from this table and gid in taxlots_in_iscrones.
--This index will speed that computation
drop index if exists tl_compare_gid_ix cascade;
create index tl_compare_gid_ix on comparison_taxlots using BTREE (gid);

--add and populate an attribute indicating whether taxlots from max_taxlots are in 
--are in comparison_taxlots
alter table comparison_taxlots drop column if exists near_max cascade;
alter table comparison_taxlots add near_max text default 'no';

update comparison_taxlots ct set near_max = 'yes'
	where ct.gid in (select ti.gid from max_taxlots ti);

--Create a mapping from MAX zones to MAX years.  Note that there are multiple years that map to 
--the CBD zone, in this case this figure is being mapped to the comparison taxlots, so I'm erring
--on the side of down playing the growth in the MAX zones by assigning the oldest year to this group
drop table if exists max_year_zone_mapping cascade;
create table max_year_zone_mapping as
	select max_zone, min(incpt_year) as max_year
	from max_stops
	group by max_zone;

--add and populate max_year column based on max_zone fields and max_stops table (indices are added
--to decrease match time)
drop index if exists tl_compare_max_zone_ix cascade;
create index tl_compare_max_zone_ix on comparison_taxlots using BTREE (max_zone);

drop index if exists max_mapping_ix cascade;
create index max_mapping_ix on max_year_zone_mapping using BTREE (max_zone);

alter table comparison_taxlots drop column if exists max_year cascade;
alter table comparison_taxlots add max_year int;

update comparison_taxlots ct set max_year = (
	select myz.max_year
	from max_year_zone_mapping myz
	where myz.max_zone = ct.max_zone);

-----------------------------------------------------------------------------------------------------------------
--Do the same for Multi-Family Housing Units

alter table trimmed_multifam drop column if exists habitable_acres cascade;
alter table trimmed_multifam add habitable_acres numeric;

update trimmed_multifam set habitable_acres = (ST_Area(geom) / 43560);

drop table if exists max_multifam cascade;
create table max_multifam with oids as
	select tm.gid, tm.geom, tm.metro_id, tm.units, tm.unit_type, tm.habitable_acres, tm.mixed_use,
		iso.max_zone, iso.walk_dist, tm.yearbuilt, min(iso.incpt_year) as max_year
	from trimmed_multifam tm
		join isochrones iso
		on ST_Intersects(tm.geom, iso.geom)
	group by tm.gid, tm.geom, tm.metro_id, tm.units, tm.yearbuilt, tm.unit_type, tm.habitable_acres, 
		tm.mixed_use, iso.max_zone, iso.walk_dist;

drop index if exists mf_in_isos_gid_ix cascade;
create index mf_in_isos_gid_ix on max_multifam using BTREE (gid);

--Divisors for overall area comparisons will still come from comparison_taxlots, but numerators
--will come from the table below.  This because the multi-family layer doesn't have full coverage
--of all buildable land in the region the way the taxlot data does
drop table if exists comparison_multifam cascade;
create table comparison_multifam with oids as
	select tm.gid, tm.geom, tm.metro_id, tm.units, tm.yearbuilt, tm.unit_type, 
		(tm.area / 43560) as acres, tm.mixed_use, 
		(select mxs.max_zone
			from max_stops mxs 
			order by tm.geom <-> mxs.geom 
			limit 1) as max_zone, 
		(select ST_Intersects(ugb.geom, tm.geom)
			from ugb) as ugb,
		(select ST_Intersects(tm.geom, tm.geom)
			from tm_district tm) as tm_dist,
		(select ST_Intersects(nc.geom, tm.geom)
			from nine_cities nc) as nine_cities
	from trimmed_multifam tm;

--Temp table is no longer needed
drop table nine_cities cascade;

drop index if exists mf_compare_gid_ix cascade;
create index mf_compare_gid_ix on comparison_multifam using BTREE (gid);

alter table comparison_multifam drop column if exists near_max cascade;
alter table comparison_multifam add near_max text default 'no';

update comparison_multifam cmf set near_max = 'yes'
	where cmf.gid in (select mfi.gid from max_multifam mfi);

drop index if exists mf_compare_max_zone_ix cascade;
create index mf_compare_max_zone_ix on comparison_multifam using BTREE (max_zone);

alter table comparison_multifam drop column if exists max_year cascade;
alter table comparison_multifam add max_year int;

update comparison_multifam cmf set max_year = (
	select myz.max_year
	from max_year_zone_mapping myz
	where myz.max_zone = cmf.max_zone);

drop table max_year_zone_mapping cascade;

--ran in 702,524 ms on 2/18/14 (definitely benefitted from some caching though)