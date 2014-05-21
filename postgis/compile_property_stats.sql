--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--This script generates figures for tax lots newly built upon deemed to have been influence by the 
--construction of MAX

--***Taxlots***

--MAX TAXLOTS

--This temp table removes duplicates that exist when taxlots are within walking distance of multiple stops
--that have different 'max zone' associations
drop table if exists max_tls_no_dupes cascade;
create temp table max_tls_no_dupes as
	select gid, geom, totalval, habitable_acres, yearbuilt, max_year, 1 as collapser
		from max_taxlots
		group by gid, geom, totalval, yearbuilt, max_year, habitable_acres;


--Group MAX tax lots by zone.  Only include those that have been built on since MAX was built for the
--total value calculation, but include all lots in zone for area calculation
drop table if exists grouped_max_tls cascade;
create temp table grouped_max_tls as
	select mt1.max_zone, 
		--The Central Business District is the only MAX zone that has areas within it that are assigned
		--to different MAX years, that issue is handled with the case statemnent below
		(case when mt1.max_zone = 'Central Business District' then 'Variable (1980, 1999, 2003)'
		 	else min(mt1.max_year)::text end) as max_year,
		mt1.walk_dist, sum(mt1.totalval) as totalval,
		(select	sum(mt2.habitable_acres)
			from max_taxlots mt2
			where mt2.max_zone = mt1.max_zone
			group by mt2.max_zone) as habitable_acres
	from max_taxlots mt1
	where yearbuilt >= max_year
	group by mt1.max_zone, mt1.walk_dist;

--Add an entry that sums the total value of new construction taxlots and total area of all taxlots near
--MAX to the table
insert into grouped_max_tls
	select 'All Zones', null, null, sum(totalval), 
		(select sum(habitable_acres)
			from max_tls_no_dupes
			group by collapser)
	from max_tls_no_dupes
	where yearbuilt >= max_year
	group by collapser;

drop table max_tls_no_dupes cascade;


----------------------------------------------------------------
--COMPARISON TAXLOTS INCLUDING MAX TAXLOTS
--Figures for tax lots newly built upon for the entire region (to be used as a baseline of comparison
--for max taxlots)

--Create a version on the comparison taxlots that elimates the duplicates
drop table if exists compare_tls_no_dupes cascade;
create temp table compare_tls_no_dupes as
	select gid, geom, totalval, yearbuilt, max_year, habitable_acres, near_max,
		tm_dist, ugb, nine_cities
	from comparison_taxlots
	group by gid, geom, totalval, yearbuilt, max_year, habitable_acres, near_max,
		tm_dist, ugb, nine_cities;


--TriMet District by Max Zone (note that some tax lots will be in the tabulation for multiple zones
--as duplicates exist in the underlying table)
drop table if exists grouped_compare_tls cascade;
create temp table grouped_compare_tls as
	select 'TM District'::text as bounds, max_zone,
		(case when max_zone ='Central Business District' then 'Variable (1980, 1999, 2003)'
			else min(max_year)::text end) as max_year,
		sum(totalval) as totalval,
		--This piece is done as sub query because I want the area for all tax lots in these regions
		--not just the ones with construction since the MAX line was built
		(select sum(ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and ct2.tm_dist is true
			group by ct2.max_zone) as habitable_acres
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and tm_dist is true
	group by ct1.max_zone, max_year;

--TM District as whole (no double counting)
insert into grouped_compare_tls
	select 'TM District', 'All Zones', null, sum(totalval),
		(select sum(cnd2.habitable_acres)
			from compare_tls_no_dupes cnd2
			where cnd2.tm_dist = cnd1.tm_dist
			group by cnd2.tm_dist)
	from compare_tls_no_dupes cnd1
	where yearbuilt >= max_year
		and tm_dist is true
	group by tm_dist;

------------------
--UGB by MAX Zone (note that some tax lots will be in the tabulation for multiple zones)
insert into grouped_compare_tls
	select 'UGB', max_zone,
		case when max_zone ='Central Business District' then 'Variable (1980, 1999, 2003)'
			else min(max_year)::text end,
		sum(totalval),
		(select sum(ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and ct2.ugb is true
			group by ct2.max_zone)
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and ugb is true
	group by max_zone, max_year;

--UGB as a whole (no double counting)
insert into grouped_compare_tls
	select 'UGB', 'All Zones', null, sum(totalval),
		(select sum(cnd2.habitable_acres)
			from compare_tls_no_dupes cnd2
			where cnd2.ugb = cnd1.ugb
			group by cnd2.ugb)
	from compare_tls_no_dupes cnd1
	where yearbuilt >= max_year
		and ugb is true
	group by ugb;

------------------
--Taxlots with the 9 most populous cities in the TriMet district (note that some tax lots will be in
--the tabulation for multiple zones)
insert into grouped_compare_tls
	select 'Nine Biggest Cities in TM District', max_zone,
		case when max_zone ='Central Business District' then 'Variable (1980, 1999, 2003)'
			else min(max_year)::text end,
		sum(totalval),
		(select sum(ct2.habitable_acres) 
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and ct2.nine_cities is true
			group by ct2.max_zone)
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and nine_cities is true
	group by max_zone, max_year;

--Nine Cities as a whole (no double counting)
insert into grouped_compare_tls
	select 'Nine Biggest Cities in TM District', 'All Zones', null, sum(totalval),
		(select sum(cnd2.habitable_acres) 
			from compare_tls_no_dupes cnd2
			where cnd2.nine_cities = cnd1.nine_cities
			group by cnd2.nine_cities)
	from compare_tls_no_dupes cnd1
	where yearbuilt >= max_year
		and nine_cities is true
	group by nine_cities;


----------------------------------------------------------------
--COMPARISON TAXLOTS EXCLUDING MAX TOAXLOTS
--Within the TriMet District, by MAX group, but doesn't not include taxlots that are within walking
--distance of MAX (note that some tax lots will be in the tabulation for multiple zones)
insert into grouped_compare_tls
	select 'TM District, not in MAX Walkshed', max_zone,
		case when max_zone ='Central Business District' then 'Variable (1980, 1999, 2003)'
			else min(max_year)::text end,
		sum(totalval),
		(select sum(ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and ct2.tm_dist is true
				and ct2.near_max is false
			group by ct2.max_zone)
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and tm_dist is true
		and near_max is false
	group by max_zone, max_year;

--TM District, not near MAX, as a whole (no double counting)
insert into grouped_compare_tls
	select 'TM District, not in MAX Walkshed', 'All Zones', null, sum(totalval),
		(select sum(cnd2.habitable_acres)
			from compare_tls_no_dupes cnd2
			where cnd2.tm_dist = cnd1.tm_dist
				and cnd2.near_max is false
			group by cnd2.tm_dist)
	from compare_tls_no_dupes cnd1
	where yearbuilt >= max_year
		and tm_dist is true
		and near_max is false
	group by tm_dist;

------------------
--UGB, not near MAX (note that some tax lots will be in the tabulation for multiple zones)
insert into grouped_compare_tls
	select 'UGB, not in MAX Walkshed', max_zone,
		case when max_zone ='Central Business District' then 'Variable (1980, 1999, 2003)'
			else min(max_year)::text end,
		sum(totalval),
		(select sum(ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and ct2.ugb is true
				and ct2.near_max is false
			group by ct2.max_zone)
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and ugb is true
		and near_max is false
	group by max_zone, max_year;

--UGB, not near MAX, as a whole (no double counting)
insert into grouped_compare_tls
	select 'UGB, not in MAX Walkshed', 'All Zones', null, sum(totalval),
		(select sum(cnd2.habitable_acres)
			from compare_tls_no_dupes cnd2
			where cnd2.ugb = cnd1.ugb
				and cnd2.near_max is false
			group by cnd2.ugb)
	from compare_tls_no_dupes cnd1
	where yearbuilt >= max_year
		and ugb is true
		and near_max is false
	group by ugb;

------------------
--Nine Cities, not near MAX (note that some tax lots will be in the tabulation for multiple zones)
insert into grouped_compare_tls
	select 'Nine Biggest Cities, not in MAX Walkshed', max_zone,
		case when max_zone ='Central Business District' then 'Variable (1980, 1999, 2003)'
			else min(max_year)::text end,
		sum(totalval),
		(select sum(ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and ct2.nine_cities is true
				and ct2.near_max is false
			group by ct2.max_zone)
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and nine_cities is true
		and near_max is false
	group by max_zone, max_year;

--Nine Cities, not near MAX, as a whole (no double counting)
insert into grouped_compare_tls
	select 'Nine Biggest Cities, not in MAX Walkshed', 'All Zones', null, sum(totalval),
		(select sum(cnd2.habitable_acres)
			from compare_tls_no_dupes cnd2
			where cnd2.nine_cities = cnd1.nine_cities
				and cnd2.near_max is false
			group by cnd2.nine_cities)
	from compare_tls_no_dupes cnd1
	where yearbuilt >= max_year
		and nine_cities is true
		and near_max is false
	group by nine_cities;

drop table compare_tls_no_dupes cascade;


-------------------------------------------------------------------------------------------------
--**Multi-family Housing Units***

--This table eliminates duplicate multi-family entries
drop table if exists max_mf_no_dupes cascade;
create temp table max_mf_no_dupes as
	select geom, units, yearbuilt, max_year, 1 as collapser
		from max_multifam
		group by gid, geom, units, yearbuilt, max_year;


--MAX MULTI-FAMILY
--MAX multifam by MAX zone, (note that some tax lots will be in the tabulation for multiple zones)
drop table if exists grouped_max_mf cascade;
create temp table grouped_max_mf as
	select max_zone, sum(units) as units
	from max_multifam mmf
	where yearbuilt >= max_year
	group by max_zone;

--MAX multifam as a whole (no double counting)
insert into grouped_max_mf
	select 'All Zones', sum(units)
	from max_mf_no_dupes
	where yearbuilt >= max_year
	group by collapser;

drop table max_mf_no_dupes cascade;


----------------------------------------------------------------
--COMPARISON MULTI-FAMILY INCLUDING MAX MULTIFAM

--Create a version on the comparison taxlots that elimates the duplicates
drop table if exists compare_mf_no_dupes cascade;
create temp table compare_mf_no_dupes as
	select gid, geom, units, yearbuilt, max_year, near_max, tm_dist, ugb, nine_cities
	from comparison_multifam
	group by gid, geom, units, yearbuilt, max_year, near_max, tm_dist, ugb, nine_cities;


--TM District by MAX Zone (note that some tax lots will be in the tabulation for multiple zones)
drop table if exists grouped_compare_mf cascade;
create temp table grouped_compare_mf as
	select 'TM District'::text as bounds, max_zone, sum(units) as units
	from comparison_multifam
	where yearbuilt >= max_year
		and tm_dist is true
	group by max_zone;

--TM District as a whole (no double counting)
insert into grouped_compare_mf
	select 'TM District', 'All Zones', sum(units)
	from compare_mf_no_dupes
	where yearbuilt >= max_year
		and tm_dist is true
	group by tm_dist;

------------------
--UGB by MAX Zone (note that some tax lots will be in the tabulation for multiple zones)
insert into grouped_compare_mf
	select 'UGB', max_zone, sum(units)
	from comparison_multifam
	where yearbuilt >= max_year
		and ugb is true
	group by max_zone;

--UGB as a whole (no double counting)
insert into grouped_compare_mf
	select 'UGB', 'All Zones', sum(units)
	from compare_mf_no_dupes
	where yearbuilt >= max_year
		and ugb is true
	group by ugb;

------------------
--Nine Cities by MAX Zone (note that some tax lots will be in the tabulation for multiple zones)
insert into grouped_compare_mf
	select 'Nine Biggest Cities in TM District', max_zone, sum(units)
	from comparison_multifam
	where yearbuilt >= max_year
		and nine_cities is true
	group by max_zone;

--Nine Cities as whole (no double counting)
insert into grouped_compare_mf
	select 'Nine Biggest Cities in TM District', 'All Zones', sum(units)
	from compare_mf_no_dupes
	where yearbuilt >= max_year
		and nine_cities is true
	group by nine_cities;


----------------------------------------------------------------
--COMPARISON MULTI-FAMILY INCLUDING MAX MULTIFAM

--TM District, not near MAX, by MAX Zone (note that some tax lots will be in the tabulation
--for multiple zones)
insert into grouped_compare_mf
	select 'TM District, not in MAX Walkshed', max_zone, sum(units)
	from comparison_multifam
	where yearbuilt >= max_year
		and tm_dist is true
		and near_max is false
	group by max_zone;

--TM District, not near MAX, as a whole (no double counting)
insert into grouped_compare_mf
	select 'TM District, not in MAX Walkshed', 'All Zones', sum(units)
	from compare_mf_no_dupes
	where yearbuilt >= max_year
		and tm_dist is true
		and near_max is false
	group by tm_dist;

------------------
--UGB, not near MAX, by MAX Zone (note that some tax lots will be in the tabulation for
--multiple zones)
insert into grouped_compare_mf
	select 'UGB, not in MAX Walkshed', max_zone, sum(units)
	from comparison_multifam
	where yearbuilt >= max_year
		and ugb is true
		and near_max is false
	group by max_zone;

--UGB, not near MAX, as a whole (no double counting)
insert into grouped_compare_mf
	select 'UGB, not in MAX Walkshed', 'All Zones', sum(units)
	from compare_mf_no_dupes
	where yearbuilt >= max_year
		and ugb is true
		and near_max is false
	group by ugb;

------------------
--Nine Cities, not near MAX, by MAX Zone (note that some tax lots will be in the tabulation
--for multiple zones)
insert into grouped_compare_mf
	select 'Nine Biggest Cities, not in MAX Walkshed', max_zone, sum(units)
	from comparison_multifam
	where yearbuilt >= max_year
		and nine_cities is true
		and near_max is false
	group by max_zone;

--Nine Cities, not near MAX, as a whole (no double counting)
insert into grouped_compare_mf
	select 'Nine Biggest Cities, not in MAX Walkshed', 'All Zones', sum(units)
	from compare_mf_no_dupes
	where yearbuilt >= max_year
		and nine_cities is true
		and near_max is false
	group by nine_cities;

drop table compare_mf_no_dupes cascade;

-------------------------------------------------------------------------------------------------
--CREATE AND POPULATE FINAL TABLE

drop table if exists property_stats cascade;
create table property_stats (
	group_desc text,
	max_zone text,
	max_year text,
	walk_distance numeric,
	totalval numeric,
	normalized_value numeric, --dollars of development per acre
	housing_units int,
	normalized_h_units numeric, --housing units per acre
	habitable_acres numeric)
with oids;

insert into property_stats
	select 'Properties in MAX Walkshed', gmt.max_zone, gmt.max_year, gmt.walk_dist, gmt.totalval,
		(gmt.totalval / gmt.habitable_acres), gmm.units, (gmm.units / gmt.habitable_acres), gmt.habitable_acres
	from grouped_max_tls gmt, grouped_max_mf gmm
	where gmt.max_zone = gmm.max_zone;

insert into property_stats
	select gt.bounds, gt.max_zone, gt.max_year, null, gt.totalval, (gt.totalval / gt.habitable_acres),
		gm.units, (gm.units / gt.habitable_acres), gt.habitable_acres
	from grouped_compare_tls gt, grouped_compare_mf gm
	where gt.max_zone = gm.max_zone
		and gt.bounds = gm.bounds;

--Temp tables no longer needed
drop table grouped_max_tls, grouped_compare_tls, grouped_max_mf, grouped_compare_mf cascade;

------------------
--POPULATE AND SORT OUTPUT STATS TABLES
--These will be written to spreadsheets

--The following attributes are being added so that the output can be formatted for presentation
alter table property_stats add group_rank int default 0;
update property_stats set group_rank = 1
	where group_desc = 'Properties in MAX Walkshed';

alter table property_stats add zone_rank int default 0;
update property_stats set zone_rank = 1
	where max_zone = 'All Zones';

--Create and populate presentation tables.  Stats are being split into those that include MAX walkshed
--taxlots for comparison and those that do not.
drop table if exists pres_stats_w_near_max cascade;
create table pres_stats_w_near_max with oids as
	select group_desc, max_zone, max_year, walk_distance, totalval, normalized_value, housing_units, normalized_h_units
	from property_stats
	where group_desc not like '%not in MAX Walkshed%'
	order by zone_rank desc, max_zone, group_rank desc, group_desc;

drop table if exists pres_stats_minus_near_max cascade;
create table pres_stats_minus_near_max with oids as
	select group_desc, max_zone, max_year, walk_distance, totalval, normalized_value, housing_units, normalized_h_units
	from property_stats
	where group_desc like '%not in MAX Walkshed%'
		OR group_desc = 'Properties in MAX Walkshed'
	order by zone_rank desc, max_zone, group_rank desc, group_desc;

--ran in 13,086 ms on 2/14 (may be benefitting from caching)