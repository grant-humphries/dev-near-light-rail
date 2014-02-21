--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--This script generates figures for tax lots newly built upon deemed to have been influence by the 
--construction of MAX

--Group MAX tax lots by zone.  Only include those that have been built on since MAX was built for the
--total value calculation, but include all lots in zone for area calculation
DROP TABLE IF EXISTS grouped_max_tls CASCADE;
CREATE TEMP TABLE grouped_max_tls AS
	SELECT mt1.max_zone, 
		--The Central Business District is the only MAX zone that has areas within it that are assigned
		--to different MAX years, that issue is handled with the case statemnent below
		(CASE WHEN mt1.max_zone = 'Central Business District' THEN 'Variable (1980, 1999, 2003)'
		 	ELSE min(mt1.max_year)::text
		 END) AS max_year,
		mt1.walk_dist, sum(mt1.totalval) AS totalval,
		(SELECT	sum(mt2.habitable_acres)
			FROM max_taxlots mt2
			WHERE mt2.max_zone = mt1.max_zone
			GROUP BY mt2.max_zone) AS habitable_acres
	FROM max_taxlots mt1
	WHERE yearbuilt >= max_year
	GROUP BY mt1.max_zone, mt1.walk_dist;

--This temp table removes duplicates that exist when taxlots are within walking distance of multiple stops
--that have different 'max zone' associations
DROP TABLE IF EXISTS tls_no_dupes CASCADE;
CREATE TEMP TABLE tls_no_dupes AS
	SELECT geom, totalval, yearbuilt, max_year, habitable_acres, 1 AS collapser
		FROM max_taxlots
		GROUP BY gid, geom, totalval, yearbuilt, max_year, habitable_acres;

--Add an entry that sums the total value of new construction taxlots and total area of all taxlots near
--MAX to the table
INSERT INTO grouped_max_tls
	SELECT 'All Zones', NULL, NULL, sum(totalval), 
		(SELECT sum(habitable_acres)
			FROM tls_no_dupes
			GROUP BY collapser)
	FROM tls_no_dupes
	WHERE yearbuilt >= max_year
	GROUP BY collapser;

DROP TABLE tls_no_dupes CASCADE;

---------------
--Figures for tax lots newly built upon for the entire region (to be used AS a baseline of comparison
--for max taxlots)

--Group 
DROP TABLE IF EXISTS grouped_tls CASCADE;
CREATE TEMP TABLE grouped_tls AS
	SELECT 'TM District'::text AS bounds, ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum(ct2.habitable_acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND tm_dist = TRUE
			GROUP BY ct2.max_zone) AS habitable_acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND tm_dist = TRUE
	GROUP BY ct1.max_zone, ct1.max_year;

--UGB
INSERT INTO grouped_tls
	SELECT 'UGB', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.habitable_acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND ugb = TRUE
			GROUP BY max_zone) AS habitable_acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND ugb = TRUE
	GROUP BY ct1.max_zone, ct1.max_year;

--Taxlots with the 9 most populous cities in the TriMet districy
INSERT INTO grouped_tls
	SELECT 'Nine Biggest Cities in TM District', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.habitable_acres) 
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND nine_cities = TRUE
			GROUP BY max_zone) AS habitable_acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND nine_cities = TRUE
	GROUP BY ct1.max_zone, ct1.max_year;

--Within the TriMet District, but doesn't not include taxlots that are within walking distance of MAX
INSERT INTO grouped_tls
	SELECT 'TM District, not in MAX Walkshed', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.habitable_acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND tm_dist = TRUE
				AND near_max = 'no'
			GROUP BY max_zone) AS habitable_acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND tm_dist = TRUE
		AND near_max = 'no'
	GROUP BY ct1.max_zone, ct1.max_year;

--UGB not near MAX
INSERT INTO grouped_tls
	SELECT 'UGB, not in MAX Walkshed', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.habitable_acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND ugb = TRUE
				AND near_max = 'no'
			GROUP BY max_zone) AS habitable_acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND ugb = TRUE
		AND near_max = 'no'
	GROUP BY ct1.max_zone, ct1.max_year;

--9 Cities not near MAX
INSERT INTO grouped_tls
	SELECT 'Nine Biggest Cities, not in MAX Walkshed', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.habitable_acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND nine_cities = TRUE
				AND near_max = 'no'
			GROUP BY max_zone) AS habitable_acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND nine_cities = TRUE
		AND near_max = 'no'
	GROUP BY ct1.max_zone, ct1.max_year;

----
--Multi-family

DROP TABLE IF EXISTS grouped_max_mf CASCADE;
CREATE TEMP TABLE grouped_max_mf AS
	SELECT max_zone, sum(units) AS units
	FROM max_multifam mmf
	WHERE yearbuilt >= max_year
	GROUP BY max_zone;

DROP TABLE IF EXISTS mf_no_dupes CASCADE;
CREATE TEMP TABLE mf_no_dupes AS
	SELECT geom, units, yearbuilt, max_year, 1 AS collapser
		FROM max_multifam
		GROUP BY gid, geom, units, yearbuilt, max_year;

INSERT INTO grouped_max_mf
	SELECT 'All Zones', sum(units)
	FROM mf_no_dupes
	WHERE yearbuilt >= max_year
	GROUP BY collapser;

DROP TABLE mf_no_dupes CASCADE;

----

DROP TABLE IF EXISTS grouped_mf CASCADE;
CREATE TEMP TABLE grouped_mf AS
	SELECT 'TM District'::text AS bounds, max_zone, sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND tm_dist = TRUE
	GROUP BY max_zone;

INSERT INTO grouped_mf
	SELECT 'UGB', max_zone, sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND ugb = TRUE
	GROUP BY max_zone;

INSERT INTO grouped_mf
	SELECT 'Nine Biggest Cities in TM District', max_zone, sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND nine_cities = TRUE
	GROUP BY max_zone;

INSERT INTO grouped_mf
	SELECT 'TM District, not in MAX Walkshed', max_zone,sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND tm_dist = TRUE
		AND near_max = 'no'
	GROUP BY max_zone;

INSERT INTO grouped_mf
	SELECT 'UGB, not in MAX Walkshed', max_zone, sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND ugb = TRUE
		AND near_max = 'no'
	GROUP BY max_zone;

INSERT INTO grouped_mf
	SELECT 'Nine Biggest Cities, not in MAX Walkshed', max_zone, sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND nine_cities = TRUE
		AND near_max = 'no'
	GROUP BY max_zone;

-------------
--Populate final tables

DROP TABLE IF EXISTS property_stats CASCADE;
CREATE TABLE property_stats (
	group_desc text,
	max_zone text,
	max_year text,
	walk_distance numeric,
	totalval numeric,
	normalized_value numeric, --dollars of development per acre
	housing_units int,
	normalized_h_units numeric, --housing units per acre
	habitable_acres numeric)
WITH OIDS;

INSERT INTO property_stats
	SELECT 'Properties in MAX Walkshed', gmt.max_zone, gmt.max_year, gmt.walk_dist, gmt.totalval,
		(gmt.totalval / gmt.habitable_acres), gmm.units, (gmm.units / gmt.habitable_acres), gmt.habitable_acres
	FROM grouped_max_tls gmt, grouped_max_mf gmm
	WHERE gmt.max_zone = gmm.max_zone;

INSERT INTO property_stats
	SELECT gt.bounds, gt.max_zone, gt.max_year, NULL, gt.totalval, (gt.totalval / gt.habitable_acres),
		gm.units, (gm.units / gt.habitable_acres), gt.habitable_acres
	FROM grouped_tls gt, grouped_mf gm
	WHERE gt.max_zone = gm.max_zone
		AND gt.bounds = gm.bounds;

--Temp tables no longer needed
DROP TABLE grouped_max_tls, grouped_tls, grouped_max_mf, grouped_mf CASCADE;

--Sum all of the 'MAX Zone' groups for the various bounding extents being used
INSERT INTO property_stats
	SELECT group_desc, 'All Zones', NULL, NULL, sum(totalval), (sum(totalval) / sum(habitable_acres)), 
	sum(housing_units), (sum(housing_units) / sum(habitable_acres)), sum(habitable_acres) 
	FROM property_stats
	--The properties near max should not be summed this way because there would be double counting
	--they've alreacdy been summed properly and inserted to the table earlier in the script
	WHERE group_desc != 'Properties in MAX Walkshed'
	GROUP BY group_desc;

--The following attributes are being added so that the output can be formatted for presentation
ALTER TABLE property_stats ADD group_rank int DEFAULT 0;
UPDATE property_stats SET group_rank = 1
	WHERE group_desc = 'Properties in MAX Walkshed';

ALTER TABLE property_stats ADD zone_rank int DEFAULT 0;
UPDATE property_stats SET zone_rank = 1
	WHERE max_zone = 'All Zones';

--Create and populate presentation tables.  Stats are being split into those that include MAX walkshed
--taxlots for comparison and those that do not.
DROP TABLE IF EXISTS pres_stats_w_near_max CASCADE;
CREATE TABLE pres_stats_w_near_max WITH OIDS AS
	SELECT group_desc, max_zone, max_year, walk_distance, totalval, normalized_value, housing_units, normalized_h_units
	FROM property_stats
	WHERE group_desc NOT LIKE '%not in MAX Walkshed%'
	ORDER BY zone_rank, max_zone, group_rank DESC, group_desc;

DROP TABLE IF EXISTS pres_stats_minus_near_max CASCADE;
CREATE TABLE pres_stats_minus_near_max WITH OIDS AS
	SELECT group_desc, max_zone, max_year, walk_distance, totalval, normalized_value, housing_units, normalized_h_units
	FROM property_stats
	WHERE group_desc LIKE '%not in MAX Walkshed%'
		OR group_desc = 'Properties in MAX Walkshed'
	ORDER BY zone_rank, max_zone, group_rank DESC, group_desc;

--ran in 13,086 ms on 2/14 (may be benefitting from caching)