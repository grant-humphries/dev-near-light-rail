--Taxlots

--Spatially join taxlots and the isocrones that were created by based places that can be reached
--within a given walking distance from MAX stops.  The output is taxlots joined to attribute information
--of the isocrones that they intersect.  Note that there are intentionally duplicates in this table if 
--a taxlot is within walking distance multiple stops that are in different 'MAX Zones'
DROP TABLE IF EXISTS max_taxlots CASCADE;
CREATE TABLE max_taxlots WITH OIDS AS
	SELECT tl.gid, tl.geom, tl.tlid, tl.totalval, tl.gis_acres as acres, tl.prop_code, tl.landuse, 
		iso.max_zone, iso.walk_dist, tl.yearbuilt, min(incpt_year) AS max_year
	FROM taxlot tl
		JOIN isocrones iso
		--This command joins two features only if they intersect
		ON ST_Intersects(tl.geom, iso.geom)
	GROUP BY tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.gis_acres, tl.prop_code, 
		tl.landuse, iso.max_zone, iso.walk_dist;

--A comparison will be done later on the gid from this table and gid in comparison_taxlots.
--This index will speed that computation
DROP INDEX IF EXISTS tl_in_isos_gid_ix CASCADE;
CREATE INDEX tl_in_isos_gid_ix ON max_taxlots USING BTREE (gid);

--Temp table will turn the 9 most populous cities in the TM district into a single geometry
DROP TABLE IF EXISTS nine_cities CASCADE;
CREATE TEMP TABLE nine_cities AS
	SELECT ST_Union(geom) AS geom
	FROM (SELECT city.gid, city.geom, 1 AS collapser
 		FROM city
 		WHERE cityname IN ('Portland', 'Gresham', 'Hillsboro', 'Beaverton', 
 			'Tualatin', 'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')) AS collapsable_city
	GROUP BY collapser;

DROP TABLE IF EXISTS comparison_taxlots CASCADE;
CREATE TABLE comparison_taxlots WITH OIDS AS
	SELECT tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.gis_acres as acres, 
		tl.prop_code, tl.landuse, 
		--Finds nearest neighbor in the max stops data set for each taxlot and returns the stop's 
		--corresponding 'MAX Zone'
		--Derived from (http://gis.stackexchange.com/questions/52792/calculate-min-distance-between-points-in-postgis)
		(SELECT mxs.max_zone
			FROM max_stops mxs 
			ORDER BY tl.geom <-> mxs.geom 
			LIMIT 1) AS max_zone,
		--Returns True if a taxlot intersects the urban growth boundary
		(SELECT ST_Intersects(ugb.geom, tl.geom)
			FROM ugb) AS ugb,
		--Returns True if a taxlot intersects the TriMet's service district boundary
		(SELECT ST_Intersects(tm.geom, tl.geom)
			FROM tm_district tm) AS tm_dist,
		--Returns True if a taxlot intersects one of the nine most populous cities in the TM dist
		(SELECT ST_Intersects(nc.geom, tl.geom)
			FROM nine_cities nc) AS nine_cities
	FROM taxlot tl;

--A comparison will be done later on the gid from this table and gid in taxlots_in_iscrones.
--This index will speed that computation
DROP INDEX IF EXISTS tl_compare_gid_ix CASCADE;
CREATE INDEX tl_compare_gid_ix ON comparison_taxlots USING BTREE (gid);

--Add and populate an attribute indicating whether taxlots from max_taxlots are in 
--are in comparison_taxlots
ALTER TABLE comparison_taxlots DROP COLUMN IF EXISTS near_max CASCADE;
ALTER TABLE comparison_taxlots ADD near_max text DEFAULT 'no';

UPDATE comparison_taxlots ct SET near_max = 'yes'
	WHERE ct.gid IN (SELECT ti.gid FROM max_taxlots ti);

--Add and populate max_year column based on max_zone fields and max_stops table (indices are added
--to decrease match time)
DROP INDEX IF EXISTS tl_compare_max_zone_ix CASCADE;
CREATE INDEX tl_compare_max_zone_ix ON comparison_taxlots USING BTREE (max_zone);

DROP INDEX IF EXISTS max_stop_zone_ix CASCADE;
CREATE INDEX max_stop_zone_ix ON max_stops USING BTREE (max_zone);

ALTER TABLE comparison_taxlots DROP COLUMN IF EXISTS max_year CASCADE;
ALTER TABLE comparison_taxlots ADD max_year int;

UPDATE comparison_taxlots ct SET max_year = (
	SELECT ms.incpt_year
	FROM max_stops ms
	WHERE ms.max_zone = ct.max_zone
	LIMIT 1);

-----------------------------------------------------------------------------------------------------------------
--Do the same for Multi-Family Housing Units

DROP TABLE IF EXISTS max_multifam CASCADE;
CREATE TABLE max_multifam WITH OIDS AS
	--43,560 square feet in an acre
	SELECT mf.gid, mf.geom, mf.metro_id, mf.units, mf.unit_type, (mf.area / 43560) as acres, mf.mixed_use,
		iso.max_zone, iso.walk_dist, mf.yearbuilt, min(iso.incpt_year) AS max_year
	FROM multi_family mf
		JOIN isocrones iso
		ON ST_Intersects(mf.geom, iso.geom)
	GROUP BY mf.gid, mf.geom, mf.metro_id, mf.units, mf.yearbuilt, mf.unit_type, mf.area, mf.mixed_use,
		iso.max_zone, iso.walk_dist;

DROP INDEX IF EXISTS mf_in_isos_gid_ix CASCADE;
CREATE INDEX mf_in_isos_gid_ix ON max_multifam USING BTREE (gid);

--Divisors for overall area comparisons will still come from comparison_taxlots, but numerators
--will come from the table below.  This because the multi-family layer doesn't have full coverage
--of all buildable land in the region the way the taxlot data does
DROP TABLE IF EXISTS comparison_multifam CASCADE;
CREATE TABLE comparison_multifam WITH OIDS AS
	SELECT mf.gid, mf.geom, mf.metro_id, mf.units, mf.yearbuilt, mf.unit_type, 
		(mf.area / 43560) as acres, mf.mixed_use, 
		(SELECT mxs.max_zone
			FROM max_stops mxs 
			ORDER BY mf.geom <-> mxs.geom 
			LIMIT 1) AS max_zone, 
		(SELECT ST_Intersects(ugb.geom, mf.geom)
			FROM ugb) AS ugb,
		(SELECT ST_Intersects(tm.geom, mf.geom)
			FROM tm_district tm) AS tm_dist,
		(SELECT ST_Intersects(nc.geom, mf.geom)
			FROM nine_cities nc) AS nine_cities
	FROM multi_family mf;

--Temp table is no longer needed
DROP TABLE nine_cities CASCADE;

DROP INDEX IF EXISTS mf_compare_gid_ix CASCADE;
CREATE INDEX mf_compare_gid_ix ON comparison_multifam USING BTREE (gid);

ALTER TABLE comparison_multifam DROP COLUMN IF EXISTS near_max CASCADE;
ALTER TABLE comparison_multifam ADD near_max text DEFAULT 'no';

UPDATE comparison_multifam cmf SET near_max = 'yes'
	WHERE cmf.gid IN (SELECT mfi.gid FROM max_multifam mfi);

DROP INDEX IF EXISTS mf_compare_max_zone_ix CASCADE;
CREATE INDEX mf_compare_max_zone_ix ON comparison_multifam USING BTREE (max_zone);

ALTER TABLE comparison_multifam DROP COLUMN IF EXISTS max_year CASCADE;
ALTER TABLE comparison_multifam ADD max_year int;

UPDATE comparison_multifam cmf SET max_year = (
	SELECT ms.incpt_year
	FROM max_stops ms
	WHERE ms.max_zone = cmf.max_zone
	LIMIT 1);

--ran in 472,601 ms (~7.9 minutes) on 2/14/14