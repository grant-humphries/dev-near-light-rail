DROP TABLE IF EXISTS taxlots_in_isocrones CASCADE;
CREATE TABLE taxlots_in_isocrones WITH OIDS AS
	SELECT tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.prop_code, tl.landuse, iso.max_zone, 
		iso.incpt_year, iso.walk_dist
	FROM taxlot tl
		JOIN isocrones iso
		ON ST_INTERSECTS(tl.geom, iso.geom)
	GROUP BY tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.prop_code, tl.landuse, iso.max_zone, 
		iso.incpt_year, iso.walk_dist;

DROP INDEX IF EXISTS tl_in_isos_gid_ix CASCADE;
CREATE INDEX tl_in_isos_gid_ix ON taxlots_in_isocrones USING BTREE gid);

--derived from (http://gis.stackexchange.com/questions/52792/calculate-min-distance-between-points-in-postgis)
DROP TABLE IF EXISTS CASCADE;
CREATE
SELECT tl.gid, tl.geom, tl.tlid, tl.totalval, tl.yearbuilt, tl.prop_code, tl.landuse, 
	(SELECT mxs.max_zone 
		FROM max_stops mxs 
		ORDER BY tl.geom <-> mxs.geom 
		LIMIT 1) as max_zone, 
	(SELECT ST_INTERSECTS(geom, tl.geom)
		FROM ugb) as ugb,
	(SELECT ST_INTERSECTS(geom, tl.geom)
		FROM tm_dist) as tm_dist,
	(SELECT ST_INTERSECTS(geom, tl.geom)
		FROM (SELECT ST_UNION(geom)
				FROM city
				WHERE cityname IN ('Portland', 'Gresham', 'Hillsboro', 'Beaverton', 'Tualatin', 
					'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')
				GROUP BY NULL)) as tm_dist,
	(SELECT ST_INTERSECTS(geom, tl.geom)
		FROM tm_dist) as near_max,

FROM taxlot tl;
