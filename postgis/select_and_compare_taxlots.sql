DROP TABLE IF EXISTS taxlots_in_isocrones CASCADE;
CREATE TABLE taxlots_in_isocrones WITH OIDS AS
	SELECT tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.prop_code, tl.landuse, iso.max_zone, 
		iso.incpt_year, iso.walk_dist
	FROM taxlot tl
		JOIN isocrones iso
		--This command joins two features only if they intersect
		ON ST_INTERSECTS(tl.geom, iso.geom)
	GROUP BY tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.prop_code, tl.landuse, iso.max_zone, 
		iso.incpt_year, iso.walk_dist;

--A comparison will be done later on the gid from this table and gid in comparison_taxlots.
--This index will speed that computation
DROP INDEX IF EXISTS tl_in_isos_gid_ix CASCADE;
CREATE INDEX tl_in_isos_gid_ix ON taxlots_in_isocrones USING BTREE (gid);

--Temp table will turn the 9 most populous cities in the TM district into a single geometry
DROP TABLE IF EXISTS nine_cities CASCADE;
CREATE TEMP TABLE nine_cities AS
	SELECT ST_UNION(geom) AS geom
	FROM (SELECT city.gid, city.geom, 1 AS collapser
 		FROM city
 		WHERE cityname IN ('Portland', 'Gresham', 'Hillsboro', 'Beaverton', 
 			'Tualatin', 'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')) AS collapsable_city
	GROUP BY collapser;

--Derived from (http://gis.stackexchange.com/questions/52792/calculate-min-distance-between-points-in-postgis)
DROP TABLE IF EXISTS comparison_taxlots CASCADE;
CREATE TABLE comparison_taxlots WITH OIDS AS
	SELECT tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.prop_code, tl.landuse, 
		--Finds nearest neighbor in the max stops data set for each taxlot and returns the stop's 
		--corresponding 'MAX Zone'
		(SELECT mxs.max_zone 
			FROM max_stops mxs 
			ORDER BY tl.geom <-> mxs.geom 
			LIMIT 1) AS max_zone, 
		--Returns True if a taxlot intersects the urban growth boundary
		(SELECT ST_INTERSECTS(geom, tl.geom)
			FROM ugb) AS ugb,
		--Returns True if a taxlot intersects the TriMet's service district boundary
		(SELECT ST_INTERSECTS(geom, tl.geom)
			FROM tm_district) AS tm_dist,
		--Returns True if a taxlot intersects one of the nine most populous cities in the TM dist
		(SELECT ST_INTERSECTS(geom, tl.geom)
			FROM nine_cities) AS nine_cities/*,
		(CASE 
			WHEN tl.gid IN (SELECT gid FROM taxlots_in_isocrones) THEN 'yes'
			ELSE 'no'
		END) AS near_max*/
	FROM taxlot tl;

--Temp table is no longer needed
DROP TABLE nine_cities CASCADE;

--A comparison will be done later on the gid from this table and gid in taxlots_in_iscrones.
--This index will speed that computation
DROP INDEX IF EXISTS tl_compare_gid_ix CASCADE;
CREATE INDEX tl_compare_gid_ix ON comparison_taxlots USING BTREE (gid);

--Add and populate an attribute indicating whether taxlots from taxlots_in_isocrones are in 
--are in comparison_taxlots
ALTER TABLE comparison_taxlots DROP COLUMN IF EXISTS near_max CASCADE;
ALTER TABLE comparison_taxlots ADD near_max text SET DEFAULT 'no';

UPDATE comparison_taxlots ct SET near_max = 'yes'
	WHERE ct.gid IN (SELECT ti.gid FROM taxlots_in_isocrones ti);