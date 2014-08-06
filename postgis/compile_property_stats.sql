--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--This script generates figures for properties near the max and built upon since the decision to
--build the nearby max line as well as stats quantify real estate growth in the Portland metro
--region as a whole, for comparison purposes

--Create versions of the taxlot- and multifam- analysis tables that remove the duplicates that exist
--when properties are within walking distance of multiple stops that have different 'max zone'
--associations, these will be used to remove double counting from regional totals
drop table if exists unique_analysis_taxlots cascade;
create table unique_analysis_taxlots with oids as
	select gid, geom, totalval, habitable_acres, yearbuilt, min(max_year) as max_year, 
		null::text as max_zone, near_max, min(walk_dist) as walk_dist, tm_dist, ugb, nine_cities
	from analysis_taxlots
	group by gid, geom, totalval, habitable_acres, yearbuilt, near_max, tm_dist, 
		ugb, nine_cities;

drop table if exists unique_analysis_multifam cascade;
create table unique_analysis_multifam with oids as
	select gid, geom, units, yearbuilt, min(max_year) as max_year, null::text as max_zone, 
		near_max, tm_dist, ugb, nine_cities
	from analysis_multifam
	group by gid, geom, units, yearbuilt, near_max, tm_dist, ugb, nine_cities;

--Create a table to store the property stats
drop table if exists property_stats cascade;
create table property_stats (
	group_desc text,
	max_zone text,
	max_year text,
	walk_dist text,
	totalval numeric,
	housing_units int,
	habitable_acres numeric,
	--these fields are for ordering the rows in the final stats table
	group_rank int,
	zone_rank int)
with oids;


--This function will generate the stats needed for this analysis from the taxlot- and multi-fam-
--analysis tables.  Each time the function is called it adds one or more entries to the property_stats
--table the contents of those entries are dictated by the function parameters
create or replace function insert_property_stats(subset text, group_method text, includes_max boolean) 
	returns void as $$
declare
	--These varaibles will be assigned values based on the function parameters
	group_desc text;
	grouping_field text;
	taxlot_table text;
	multifam_table text;
	
	--These variables may or may not be assigned values (other than empty string/zero) based
	--on the function parameters
	zone_clause text := '';
	not_near_max_clause text := '';
	group_rank text := '0';
	zone_rank text := '0';
begin
	--the subset parameter defines portion of the properties that are being described 
	--the current entr(ies)
	if subset = 'near_max' then
		group_desc := 'Properties in MAX Walkshed';
		group_rank := '1';
	elsif subset = 'ugb' then
		group_desc := 'UGB';
	elsif subset = 'tm_dist' then
		group_desc := 'TriMet District';
	elsif subset = 'nine_cities' then
		group_desc := 'Nine Biggest Cities in TM District';
	else
		raise notice 'invalid input for ''subset'' parameter,';
		raise notice 'enter ''near_max'', ''ugb'', ''tm_dist'', or ''nine_cities''.';
	end if;

	--group_method determines whether a set of entries will be created for each max zone
	--within the current subset or whether a single entry will be created that describes the
	--subset as a whole.  The same property can belong to multiple max zones and will be
	--counted in each, but the former type of entry eliminates as duplicates
	if group_method = 'by_zone' then
		grouping_field := 'max_zone';
		taxlot_table := 'analysis_taxlots ';
		multifam_table := 'analysis_multifam ';
		zone_clause := 'AND max_zone = tx1.max_zone ';
	elsif group_method = 'by_subset' then
		grouping_field := subset;
		taxlot_table := 'unique_analysis_taxlots ';
		multifam_table := 'unique_analysis_multifam ';
		zone_rank := '1';
	else
		raise notice 'invalid input for ''group_method'' parameter,';
		raise notice 'enter ''by_zone'' or ''by_subset''.';
	end if;

	--the includes_max parameters indicates whether the properties within walking distance of
	--max stops are to be included in the stats for the current entry
	if includes_max is false then
		group_desc := group_desc || ', not in MAX Walkshed';
		not_near_max_clause := 'AND near_max IS FALSE ';
	elsif includes_max != true then
		raise notice 'invalid input for ''includes_max'' parameter, must be a boolean';
	end if;

	--the quey below is pieced together based on the function parameters
	execute 'INSERT INTO property_stats '
				|| 'SELECT ' || quote_literal(group_desc) || '::text, '
					|| 'COALESCE(STRING_AGG(DISTINCT max_zone, '', ''), ''All Zones''), '
					|| 'ARRAY_TO_STRING(ARRAY_AGG(DISTINCT max_year ORDER BY max_year), '', ''), '
					|| 'STRING_AGG(DISTINCT COALESCE(walk_dist::int::text, ''n/a''), '' & ''), '
					|| 'SUM(totalval), '
					|| '(SELECT SUM(units) '
						|| 'FROM ' || multifam_table
						|| 'WHERE yearbuilt >= max_year '
							|| 'AND ' || subset || ' IS TRUE '
							|| zone_clause
							|| not_near_max_clause
						|| 'GROUP BY ' || grouping_field || '), '
					|| '(SELECT SUM(habitable_acres) '
						|| 'FROM ' || taxlot_table
						|| 'WHERE ' || subset || ' IS TRUE '
							|| zone_clause
							|| not_near_max_clause
						|| 'GROUP BY ' || grouping_field || '), '
					|| group_rank || ', ' || zone_rank || ' '
				|| 'FROM ' || taxlot_table || 'tx1 '
				|| 'WHERE yearbuilt >= max_year '
					|| 'AND ' || subset || ' IS TRUE '
					|| not_near_max_clause
				|| 'GROUP BY ' || grouping_field;
end;
$$ language plpgsql;

--Properties within walking distance of MAX
select insert_property_stats('near_max', 'by_zone', true);
select insert_property_stats('near_max', 'by_subset', true);

--Comparison properties *including* those within walking distance of MAX
select insert_property_stats('ugb', 'by_zone', true);
select insert_property_stats('ugb', 'by_subset', true);
select insert_property_stats('tm_dist', 'by_zone', true);
select insert_property_stats('tm_dist', 'by_subset', true);
select insert_property_stats('nine_cities', 'by_zone', true);
select insert_property_stats('nine_cities', 'by_subset', true);

--Comparison properties *excluding* those within walking distance of MAX
select insert_property_stats('ugb', 'by_zone', false);
select insert_property_stats('ugb', 'by_subset', false);
select insert_property_stats('tm_dist', 'by_zone', false);
select insert_property_stats('tm_dist', 'by_subset', false);
select insert_property_stats('nine_cities', 'by_zone', false);
select insert_property_stats('nine_cities', 'by_subset', false);


------------------
--Populate and sort output stats tables, these will be written to (csv) spreadsheets

--Create and populate presentation tables.  Stats are being split into those that include MAX walkshed
--taxlots for comparison and those that do not.
drop table if exists pres_stats_w_near_max cascade;
create table pres_stats_w_near_max with oids as
	select group_desc, max_zone, max_year, walk_dist, totalval, housing_units,
		round(habitable_acres, 2) as habitable_acres,
		round(totalval / habitable_acres) as normalized_totval, 
		round(housing_units / habitable_acres, 2) as normalized_units
	from property_stats
	where group_desc not like '%not in MAX Walkshed%'
	order by zone_rank desc, max_zone, group_rank desc, group_desc;

drop table if exists pres_stats_minus_near_max cascade;
create table pres_stats_minus_near_max with oids as
	select group_desc, max_zone, max_year, walk_dist, totalval, housing_units,
		round(habitable_acres, 2) as habitable_acres,
		round(totalval / habitable_acres) as normalized_totval, 
		round(housing_units / habitable_acres, 2) as normalized_units
	from property_stats
	where group_desc like '%not in MAX Walkshed%'
		OR group_desc = 'Properties in MAX Walkshed'
	order by zone_rank desc, max_zone, group_rank desc, group_desc;

--ran in 73,784 ms on 8/5/14