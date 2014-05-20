--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--This script generates figures for tax lots newly built upon deemed to have been influence by the 
--construction of MAX

--Group MAX tax lots by zone.  Only include those that have been built on since MAX was built for the
--total value calculation, but include all lots in zone for area calculation
drop table if exists grouped_max_tls cascade;
create temp table grouped_max_tls as
	select mt1.max_zone, 
		--The Central Business District is the only MAX zone that has areas within it that are assigned
		--to different MAX years, that issue is handled with the case statemnent below
		(case when mt1.max_zone = 'Central Business District' then 'Variable (1980, 1999, 2003)'
		 	else min(mt1.max_year)::text
		 end) as max_year,
		mt1.walk_dist, sum(mt1.totalval) as totalval,
		(select	sum(mt2.habitable_acres)
			from max_taxlots mt2
			where mt2.max_zone = mt1.max_zone
			group by mt2.max_zone) as habitable_acres
	from max_taxlots mt1
	where yearbuilt >= max_year
	group by mt1.max_zone, mt1.walk_dist;

--This temp table removes duplicates that exist when taxlots are within walking distance of multiple stops
--that have different 'max zone' associations
drop table if exists tls_no_dupes cascade;
create temp table tls_no_dupes as
	select geom, totalval, yearbuilt, max_year, habitable_acres, 1 as collapser
		from max_taxlots
		group by gid, geom, totalval, yearbuilt, max_year, habitable_acres;

--Add an entry that sums the total value of new construction taxlots and total area of all taxlots near
--MAX to the table
insert into grouped_max_tls
	select 'All Zones', null, null, sum(totalval), 
		(select sum(habitable_acres)
			from tls_no_dupes
			group by collapser)
	from tls_no_dupes
	where yearbuilt >= max_year
	group by collapser;

drop table tls_no_dupes cascade;

---------------
--Figures for tax lots newly built upon for the entire region (to be used as a baseline of comparison
--for max taxlots)

--Group 
drop table if exists grouped_tls cascade;
create temp table grouped_tls as
	select 'TM District'::text as bounds, ct1.max_zone, ct1.max_year, sum(ct1.totalval) as totalval,
		(select sum(ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and tm_dist = true
			group by ct2.max_zone) as habitable_acres
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and tm_dist = true
	group by ct1.max_zone, ct1.max_year;

--UGB
insert into grouped_tls
	select 'UGB', ct1.max_zone, ct1.max_year, sum(ct1.totalval) as totalval,
		(select sum (ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and ugb = true
			group by max_zone) as habitable_acres
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and ugb = true
	group by ct1.max_zone, ct1.max_year;

--Taxlots with the 9 most populous cities in the TriMet districy
insert into grouped_tls
	select 'Nine Biggest Cities in TM District', ct1.max_zone, ct1.max_year, sum(ct1.totalval) as totalval,
		(select sum (ct2.habitable_acres) 
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and nine_cities = true
			group by max_zone) as habitable_acres
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and nine_cities = true
	group by ct1.max_zone, ct1.max_year;

--Within the TriMet District, but doesn't not include taxlots that are within walking distance of MAX
insert into grouped_tls
	select 'TM District, not in MAX Walkshed', ct1.max_zone, ct1.max_year, sum(ct1.totalval) as totalval,
		(select sum (ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and tm_dist = true
				and near_max = 'no'
			group by max_zone) as habitable_acres
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and tm_dist = true
		and near_max = 'no'
	group by ct1.max_zone, ct1.max_year;

--UGB not near MAX
insert into grouped_tls
	select 'UGB, not in MAX Walkshed', ct1.max_zone, ct1.max_year, sum(ct1.totalval) as totalval,
		(select sum (ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and ugb = true
				and near_max = 'no'
			group by max_zone) as habitable_acres
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and ugb = true
		and near_max = 'no'
	group by ct1.max_zone, ct1.max_year;

--9 Cities not near MAX
insert into grouped_tls
	select 'Nine Biggest Cities, not in MAX Walkshed', ct1.max_zone, ct1.max_year, sum(ct1.totalval) as totalval,
		(select sum (ct2.habitable_acres)
			from comparison_taxlots ct2
			where ct2.max_zone = ct1.max_zone
				and nine_cities = true
				and near_max = 'no'
			group by max_zone) as habitable_acres
	from comparison_taxlots ct1
	where yearbuilt >= max_year
		and nine_cities = true
		and near_max = 'no'
	group by ct1.max_zone, ct1.max_year;

----
--Multi-family

drop table if exists grouped_max_mf cascade;
create temp table grouped_max_mf as
	select max_zone, sum(units) as units
	from max_multifam mmf
	where yearbuilt >= max_year
	group by max_zone;

drop table if exists mf_no_dupes cascade;
create temp table mf_no_dupes as
	select geom, units, yearbuilt, max_year, 1 as collapser
		from max_multifam
		group by gid, geom, units, yearbuilt, max_year;

insert into grouped_max_mf
	select 'All Zones', sum(units)
	from mf_no_dupes
	where yearbuilt >= max_year
	group by collapser;

drop table mf_no_dupes cascade;

----

drop table if exists grouped_mf cascade;
create temp table grouped_mf as
	select 'TM District'::text as bounds, max_zone, sum(units) as units
	from comparison_multifam
	where yearbuilt >= max_year
		and tm_dist = true
	group by max_zone;

insert into grouped_mf
	select 'UGB', max_zone, sum(units) as units
	from comparison_multifam
	where yearbuilt >= max_year
		and ugb = true
	group by max_zone;

insert into grouped_mf
	select 'Nine Biggest Cities in TM District', max_zone, sum(units) as units
	from comparison_multifam
	where yearbuilt >= max_year
		and nine_cities = true
	group by max_zone;

insert into grouped_mf
	select 'TM District, not in MAX Walkshed', max_zone,sum(units) as units
	from comparison_multifam
	where yearbuilt >= max_year
		and tm_dist = true
		and near_max = 'no'
	group by max_zone;

insert into grouped_mf
	select 'UGB, not in MAX Walkshed', max_zone, sum(units) as units
	from comparison_multifam
	where yearbuilt >= max_year
		and ugb = true
		and near_max = 'no'
	group by max_zone;

insert into grouped_mf
	select 'Nine Biggest Cities, not in MAX Walkshed', max_zone, sum(units) as units
	from comparison_multifam
	where yearbuilt >= max_year
		and nine_cities = true
		and near_max = 'no'
	group by max_zone;

-------------
--Populate final tables

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
	from grouped_tls gt, grouped_mf gm
	where gt.max_zone = gm.max_zone
		and gt.bounds = gm.bounds;

--Temp tables no longer needed
drop table grouped_max_tls, grouped_tls, grouped_max_mf, grouped_mf cascade;

--Sum all of the 'MAX Zone' groups for the various bounding extents being used
insert into property_stats
	select group_desc, 'All Zones', null, null, sum(totalval), (sum(totalval) / sum(habitable_acres)), 
	sum(housing_units), (sum(housing_units) / sum(habitable_acres)), sum(habitable_acres) 
	from property_stats
	--The properties near max should not be summed this way because there would be double counting
	--they've alreacdy been summed properly and inserted to the table earlier in the script
	where group_desc != 'Properties in MAX Walkshed'
	group by group_desc;

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
	order by zone_rank, max_zone, group_rank desc, group_desc;

drop table if exists pres_stats_minus_near_max cascade;
create table pres_stats_minus_near_max with oids as
	select group_desc, max_zone, max_year, walk_distance, totalval, normalized_value, housing_units, normalized_h_units
	from property_stats
	where group_desc like '%not in MAX Walkshed%'
		OR group_desc = 'Properties in MAX Walkshed'
	order by zone_rank, max_zone, group_rank desc, group_desc;

--ran in 13,086 ms on 2/14 (may be benefitting from caching)