--Figures for tax lots newly built upon deemed to have been influence by the construction of MAX

--Group MAX tax lots by zone.  Only include those that have been built on since MAX was built for the
--total value calculation, but include all lots in zone for area calculation
DROP TABLE IF EXISTS grouped_max_tls CASCADE;
CREATE TEMP TABLE grouped_max_tls AS
	SELECT mt1.max_zone, mt1.max_year, mt1.walk_dist, sum(mt1.totalval) AS totalval,
		(SELECT	sum(mt2.acres)
			FROM max_taxlots mt2
			WHERE mt2.max_zone = mt1.max_zone
			GROUP BY mt2.max_zone) AS acres
	FROM max_taxlots mt1
	WHERE yearbuilt >= max_year
	GROUP BY mt1.max_zone, mt1.max_year, mt1.walk_dist;

--This temp table removes duplicates that exist when taxlots are within walking distance of multiple stops
--that have different 'max zone' associations
DROP TABLE IF EXISTS tls_no_dupes CASCADE;
CREATE TEMP TABLE tls_no_dupes AS
	SELECT geom, totalval, yearbuilt, max_year, acres, 1 AS collapser
		FROM max_taxlots
		GROUP BY gid, geom, totalval, yearbuilt, max_year, acres;

--Add an entry that sums the total value of new construction taxlots and total area of all taxlots near
--MAX to the table
INSERT INTO grouped_max_tls
	SELECT 'All Zones', NULL, NULL, sum(totalval), 
		(SELECT sum(acres)
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
		(SELECT sum(ct2.acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND tm_dist = TRUE
			GROUP BY ct2.max_zone) AS acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND tm_dist = TRUE
	GROUP BY ct1.max_zone, ct1.max_year;

--UGB
INSERT INTO grouped_tls
	SELECT 'UGB', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND ugb = TRUE
			GROUP BY max_zone) AS acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND ugb = TRUE
	GROUP BY ct1.max_zone, ct1.max_year;

--Taxlots with the 9 most populous cities in the TriMet districy
INSERT INTO grouped_tls
	SELECT 'Nine Most Populous Cities', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.acres) 
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND nine_cities = TRUE
			GROUP BY max_zone) AS acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND nine_cities = TRUE
	GROUP BY ct1.max_zone, ct1.max_year;

--Within the TriMet District, but doesn't not include taxlots that are within walking distance of MAX
INSERT INTO grouped_tls
	SELECT 'TM District not Near MAX', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND tm_dist = TRUE
				AND near_max = 'no'
			GROUP BY max_zone) AS acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND tm_dist = TRUE
		AND near_max = 'no'
	GROUP BY ct1.max_zone, ct1.max_year;

--UGB not near MAX
INSERT INTO grouped_tls
	SELECT 'UGB not Near MAX', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND ugb = TRUE
				AND near_max = 'no'
			GROUP BY max_zone) AS acres
	FROM comparison_taxlots ct1
	WHERE yearbuilt >= max_year
		AND ugb = TRUE
		AND near_max = 'no'
	GROUP BY ct1.max_zone, ct1.max_year;

--9 Cities not near MAX
INSERT INTO grouped_tls
	SELECT 'Nine Cities not Near MAX', ct1.max_zone, ct1.max_year, sum(ct1.totalval) AS totalval,
		(SELECT sum (ct2.acres)
			FROM comparison_taxlots ct2
			WHERE ct2.max_zone = ct1.max_zone
				AND nine_cities = TRUE
				AND near_max = 'no'
			GROUP BY max_zone) AS acres
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
	SELECT 'Nine Most Populous Cities', max_zone, sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND nine_cities = TRUE
	GROUP BY max_zone;

INSERT INTO grouped_mf
	SELECT 'TM District not Near MAX', max_zone,sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND tm_dist = TRUE
		AND near_max = 'no'
	GROUP BY max_zone;

INSERT INTO grouped_mf
	SELECT 'UGB not Near MAX', max_zone, sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND ugb = TRUE
		AND near_max = 'no'
	GROUP BY max_zone;

INSERT INTO grouped_mf
	SELECT 'Nine Cities not Near MAX', max_zone, sum(units) AS units
	FROM comparison_multifam
	WHERE yearbuilt >= max_year
		AND nine_cities = TRUE
		AND near_max = 'no'
	GROUP BY max_zone;

-------------
--Populate final table

DROP TABLE IF EXISTS property_stats CASCADE;
CREATE TABLE property_stats (
	group_desc text,
	max_zone text,
	max_year int,
	walk_distance numeric,
	totalval numeric,
	normalized_value numeric, --dollars of development per acre
	housing_units int,
	normalized_h_units numeric, --housing units per acre
	acres numeric)
WITH OIDS;

INSERT INTO property_stats
	SELECT 'Properties Near MAX', gmt.max_zone, gmt.max_year, gmt.walk_dist, gmt.totalval,
		(gmt.totalval / gmt.acres), gmm.units, (gmm.units / gmt.acres), gmt.acres
	FROM grouped_max_tls gmt, grouped_max_mf gmm
	WHERE gmt.max_zone = gmm.max_zone;

INSERT INTO property_stats
	SELECT gt.bounds, gt.max_zone, gt.max_year, NULL, gt.totalval, (gt.totalval / gt.acres),
		gm.units, (gm.units / gt.acres), gt.acres
	FROM grouped_tls gt, grouped_mf gm
	WHERE gt.max_zone = gm.max_zone
		AND gt.bounds = gm.bounds;

--Temp tables no longer needec
DROP TABLE grouped_max_tls, grouped_tls, grouped_max_mf, grouped_mf CASCADE;

INSERT INTO property_stats
	SELECT group_desc, 'All Zones', NULL, NULL, sum(totalval), (sum(totalval) / sum(acres)), 
	sum(housing_units), (sum(housing_units) / sum(acres)), sum(acres) 
	FROM property_stats
	--The properties near max should not be summed this way because there would be double counting
	--they've alreacy been summed properly and inserted to the table
	WHERE group_desc != 'Properties Near MAX'
	GROUP BY group_desc;

--ran in 12,221 ms on 2/14