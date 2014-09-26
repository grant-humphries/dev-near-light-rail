--Grant Humphries for TriMet, 2013-14
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--Below are two solutions that erase water bodies and natural areas from taxlots.  At this time this 
--process takes too long in PostGIS to be viable, but I learned a bit writing these and want to keep 
--them on hand.  I believe the long execution time here has more to do with the platform than inefficent
--query writing as I found a post by one of the PostGIS developer tackling a similar subject and he stated
--that very long run times should be expected in this case.  I ended up implemneting this in arcPy as their
--methodology is more effiecient for this kind of operation

--Load the geometry for parks and water into a single table with an attribute that allows all the features
--to be groupted together
DROP TABLE IF EXISTS water_and_parks CASCADE;
CREATE TEMP TABLE water_and_parks AS
	SELECT geom, 1 AS collapser
	FROM water;

INSERT INTO water_and_parks
	SELECT geom, 1
	FROM orca;

--Create a single geometry for all park and water features
DROP TABLE IF EXISTS erase1geom CASCADE;
CREATE TEMP TABLE erase1geom AS
	SELECT ST_Union(geom) AS geom
	FROM (water_and_parks
	GROUP BY collapser;

--Erase water and park features from taxlot polygons
DROP TABLE IF EXISTS taxlots_trimmed CASCADE;
CREATE TABLE taxlots_trimmed AS
	--The ST_Union function may need to be within a ST_Multi function for this to work properly
	SELECT COALESCE(ST_Difference(tl.geom, ST_Union(e1g.geom)), tl.geom) AS geom, tl.gid, tl.tlid
	FROM (SELECT
			FROM taxlot tl
			LEFT JOIN erase1geom e1g
			ON ST_Intersects(tl.geom, e1g.geom)) AS;

---------------------------------------------------------------------
--Alternate solution.  Not sure which one is faster because they both take so long to complete that I
--haven't run them all the way through, but I'm guessing that it's the former.

DROP TABLE IF EXISTS taxlots_trimmed CASCADE;
CREATE TABLE taxlots_trimmed AS
	--Not clear on weather ST_Multi is need here or not
	SELECT COALESCE(ST_Difference(tl.geom, ST_Multi(ST_Union(wp.geom))), tl.geom) AS geom, tl.gid, tl.tlid
	FROM taxlot tl
		LEFT JOIN water_and_parks wp
		ON ST_Intersects(tl.geom, wp.geom)
	--I'm unsure as to whether or not it is computationally intensice to group tables by geometry, if
	--that's the case it likely makes sense to take another approach this is not critical to the query
	--UPDATE: I found that group by geometry only compares bounding boxes, not the full feature, but
	--still not sure how intensive that action is
	GROUP BY tl.geom, tl.gid, tl.tlid;

DROP TABLE water_and_parks, erase1geom CASCADE;