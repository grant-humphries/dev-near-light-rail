--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--***Taxlots***

--Since parks and water bodies have been 'erased' for taxlots in previous steps the attribute that
--ships with RLIS and contains the area of the feature is no longer valid and the area will be
--recalculated below
alter table trimmed_taxlots drop column if exists habitable_acres cascade;
alter table trimmed_taxlots add habitable_acres numeric;

--Since this data set is in the State Plane projection the output of the ST_Area tool will be in 
--square feet, I want acres and thus will divide that number by 43,560 as that's how many square 
--feet are in an acre
update trimmed_taxlots set habitable_acres = (ST_Area(geom) / 43560);

--------------------------
--CREATE MAX TAXLOTS
--Spatially join taxlots and the isochrones (the former of which indicates area that are within a given
--wlaking distance of max stops).  The output is taxlots joined to attribute information of the isochrones
--that they intersect.  Note that there are intentionally duplicates in this table if a taxlot is within
--walking distance multiple stops that are in different 'MAX Zones', but duplicates of the same property
--joined to the same zone are eliminated
drop table if exists max_taxlots cascade;
create table max_taxlots with oids as
	select tt.gid, tt.geom, tt.tlid, tt.totalval, tt.habitable_acres, tt.prop_code, tt.landuse,
		tt.yearbuilt, min(iso.incpt_year) as max_year, iso.max_zone, iso.walk_dist
	from trimmed_taxlots tt
		join isochrones iso
		--This command joins two features only if they intersect
		on ST_Intersects(tt.geom, iso.geom)
	group by tt.gid, tt.geom, tt.tlid, tt.totalval, tt.habitable_acres, tt.prop_code, tt.landuse,
		tt.yearbuilt, iso.max_zone, iso.walk_dist;

--Add index to improve performance on comparisions done on this field
drop index if exists tl_in_isos_gid_ix cascade;
create index tl_in_isos_gid_ix on max_taxlots using BTREE (gid);

vacuum analyze max_taxlots;

--------------------------
--CREATE COMPARISON TAXLOTS
drop table if exists comparison_taxlots cascade;
create table comparison_taxlots (
	gid int references trimmed_taxlots, 
	geom geometry,
	tlid text,
	totalval numeric,
	habitable_acres numeric,
	prop_code text,
	landuse text,
	yearbuilt int,
	max_year int,
	max_zone text,
	near_max boolean,
	ugb boolean,
	tm_dist boolean,
	nine_cities boolean)
with oids;

--should speed performance on nearest neighbor operation below
cluster trimmed_taxlots using trimmed_taxlots_geom_gist;
analyze trimmed_taxlots;

--Insert taxlots that are not within walking distance of max stops into comparison-taxlots 
insert into comparison_taxlots (gid, geom, tlid, totalval, habitable_acres, prop_code,
		landuse, yearbuilt, max_zone, near_max)
	select tt.gid, tt.geom, tt.tlid, tt.totalval, tt.habitable_acres, 
		tt.prop_code, tt.landuse, tt.yearbuilt, 
		--Finds nearest neighbor in the max stops data set for each taxlot and returns the stop's 
		--corresponding 'MAX Zone' (a zone was assigned to each stop earlier in the project),
		--derived from (http://gis.stackexchange.com/questions/52792/calculate-min-distance-between-points-in-postgis)
		(select mxs.max_zone
			from max_stops mxs 
			order by tt.geom <-> mxs.geom 
			limit 1), false
	from trimmed_taxlots tt
	where tt.gid not in (select mt.gid from max_taxlots mt);

vacuum analyze comparison_taxlots;

--Assign the max year based on the max zone, this method is being used because repeating the 
--nearest neighbor method to get the year is far more time consuming

--Create a mapping from MAX zones to MAX years. Note that there are multiple years that map to the
--CBD zone and in this case the minimum year will be returned
drop table if exists max_year_zone_mapping cascade;
create temp table max_year_zone_mapping as
	select max_zone, min(incpt_year) as max_year
	from max_stops
	group by max_zone;

--Index is added to decrease match time below
drop index if exists max_mapping_ix cascade;
create index max_mapping_ix on max_year_zone_mapping using BTREE (max_zone);

--Populate max_year column based on max_year_zone_mapping table.  Again there are multiple years that
--map to the CBD, but most of those tax lots are within walking distance of max stop and are coming
--from the max-taxlots table.
update comparison_taxlots ct set max_year = yzm.max_year
	from max_year_zone_mapping yzm
	where yzm.max_zone = ct.max_zone;

--Insert max-taxlots into comparison-taxlots, there will be duplicates in cases where tax lots are
--within walking distance of two stops in different max zones
insert into comparison_taxlots (gid, geom, tlid, totalval, yearbuilt, habitable_acres, prop_code,
		landuse, max_zone, max_year, near_max)
	select mt.gid, mt.geom, mt.tlid, mt.totalval, mt.yearbuilt, mt.habitable_acres, 
		mt.prop_code, mt.landuse, mt.max_zone, mt.max_year, true
	from max_taxlots mt;

--Add index to improve performance on upcming spatial comparisons
drop index if exists tl_compare_gix cascade;
create index tl_compare_gix on comparison_taxlots using GIST (geom);

cluster comparison_taxlots using tl_compare_gix;
vacuum analyze comparison_taxlots;

--Temp table will turn the 9 most populous cities in the TM district into a single geometry
drop table if exists nine_cities cascade;
create temp table nine_cities as
	select ST_Union(geom) as geom
	from (select city.gid, city.geom, 1 as collapser
 		from city
 		where cityname in ('Portland', 'Gresham', 'Hillsboro', 'Beaverton', 
 			'Tualatin', 'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')) as collapsable_city
	group by collapser;

--Determine if each of the comparison texlots is in the trimet district, urban growth boundary, 
--and city limits of the nine biggest cities in the Portland metro area (Oregon only)
update comparison_taxlots as ct set
	--Returns True if a taxlot intersects the urban growth boundary
	ugb = (select ST_Intersects(ugb.geom, ct.geom)
		from ugb),
	--Returns True if a taxlot intersects the TriMet's service district boundary
	tm_dist = (select ST_Intersects(td.geom, ct.geom)
		from tm_district td),
	--Returns True if a taxlot intersects one of the nine most populous cities in the TM dist
	nine_cities = (select ST_Intersects(nc.geom, ct.geom)
		from nine_cities nc);


-----------------------------------------------------------------------------------------------------------------
--***Multi-Family Housing Units***
--Works off the same framework as what is used for tax lots above

alter table trimmed_multifam drop column if exists habitable_acres cascade;
alter table trimmed_multifam add habitable_acres numeric;

update trimmed_multifam set habitable_acres = (ST_Area(geom) / 43560);

--------------------------
--CREATE MAX MULTIFAM
drop table if exists max_multifam cascade;
create table max_multifam with oids as
	select tm.gid, tm.geom, tm.metro_id, tm.units, tm.unit_type, tm.habitable_acres, tm.mixed_use,
		tm.yearbuilt, min(iso.incpt_year) as max_year, iso.max_zone, iso.walk_dist
	from trimmed_multifam tm
		join isochrones iso
		on ST_Intersects(tm.geom, iso.geom)
	group by tm.gid, tm.geom, tm.metro_id, tm.units, tm.yearbuilt, tm.unit_type, tm.habitable_acres, 
		tm.mixed_use, iso.max_zone, iso.walk_dist;

drop index if exists mf_in_isos_gid_ix cascade;
create index mf_in_isos_gid_ix on max_multifam using BTREE (gid);

vacuum analyze max_multifam;

--------------------------
--CREATE COMPARISON MULTIFAM
--Divisors for overall area comparisons will still come from comparison_taxlots, but numerators
--will come from the table below.  This because the multi-family layer doesn't have full coverage
--of all buildable land in the region the way the taxlot data does
drop table if exists comparison_multifam cascade;
create table comparison_multifam (
	gid int references trimmed_multifam, 
	geom geometry,
	metro_id int,
	units int,
	unit_type text,
	habitable_acres numeric,
	mixed_use int,
	yearbuilt int,
	max_year int,
	max_zone text,
	near_max boolean,
	ugb boolean,
	tm_dist boolean,
	nine_cities boolean)
with oids;

cluster trimmed_multifam using trimmed_multifam_geom_gist;
analyze trimmed_multifam;

--Insert multifam units outside of walking distance into the comparison-multifam
insert into comparison_multifam (gid, geom, metro_id, units, unit_type, habitable_acres,
		mixed_use, yearbuilt, max_zone, near_max)
	select tm.gid, tm.geom, tm.metro_id, tm.units, tm.unit_type, tm.habitable_acres,
		tm.mixed_use, tm.yearbuilt,
		--get max zone for nearest stop using nearest neighbor
		(select mxs.max_zone
			from max_stops mxs 
			order by tm.geom <-> mxs.geom 
			limit 1), false
	from trimmed_multifam tm
	where tm.gid not in (select mm.gid from max_multifam mm);

vacuum analyze comparison_multifam;

--Populate max_year column for properties outside max stop walking distance based on
--max_year_zone_mapping table
update comparison_multifam cm set max_year = yzm.max_year
	from max_year_zone_mapping yzm
	where yzm.max_zone = cm.max_zone;

--Insert max-multifam units into comparison-multifam (there will be some duplicates)
insert into comparison_multifam (gid, geom, metro_id, units, unit_type, habitable_acres,
		mixed_use, yearbuilt, max_year, max_zone, near_max)
	select mm.gid, mm.geom, mm.metro_id, mm.units, mm.unit_type, mm.habitable_acres,
		mm.mixed_use, mm.yearbuilt, mm.max_year, mm.max_zone, true
	from max_multifam mm;

--Should improve performance on upcoming spatial comparisons
drop index if exists mf_compare_gix cascade;
create index mf_compare_gix on comparison_multifam using GIST (geom);

cluster comparison_multifam using mf_compare_gix;
vacuum analyze comparison_multifam;

update comparison_multifam as cm set
	ugb = (select ST_Intersects(ugb.geom, cm.geom)
		from ugb),

	tm_dist = (select ST_Intersects(td.geom, cm.geom)
		from tm_district td),

	nine_cities = (select ST_Intersects(nc.geom, cm.geom)
		from nine_cities nc);

--Temp table is no longer needed
drop table max_year_zone_mapping cascade;
drop table nine_cities cascade;

--ran in 702,524 ms on 2/18/14 (definitely benefitted from some caching though)