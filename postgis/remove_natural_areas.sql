--Grant Humphries for TriMet, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--This script creates tables that contains only properties that are less than
--80% covered by natural areas.  This method was developed to replace the technique
--of erasing the geometry of the natural areas from the geometry of the tax lots
--because that left small fragements in some case where the datasets didn't align

--Much of the work here is derived from this post:
--http://gis.stackexchange.com/questions/31310/acquiring-arcgis-like-speed-in-postgis

--Create a table that containings polygons that are the intersection of the
--taxlot and orca datasets, then union any geometry that are derived from 
--same taxlot
drop table if exists orca_taxlots cascade;
create table orca_taxlots with oids as
	select gid, ST_Multi(ST_Union(geom)) as geom, action_type
	from (select tl.gid, 
			--this case statement prevents taxlots completely within natural areas
			--from having to go through the costly st_intersection step
			cases
				when ST_Within(tl.geom, o.geom) then tl.geom
				else ST_Multi(ST_Intersection(tl.geom, o.geom))
			end as geom, 
			case
				when ST_Within(tl.geom, o.geom) then 'drop'
				else 'compare'
			end as action_type
		from taxlots tl, 
			(select gid, geom
			from orca
			--some orca types aren't considered natural areas for the purposes of
			--this project, those are filtered out below
			where unittype in ('Cemetery', 'Golf Course', 'Natural Area', 'Park')) o
		--first filtering the data this way instead of running everything through
		--st_intersection is a big time saver
		where ST_Intersects(tl.geom, o.geom)) pre_o_taxlots
	group by gid, action_type;

--Now filter out any tax lots that are at least 80% covered by natural areasS
drop table if exists cleaned_taxlots cascade;
create table cleaned_taxlots with oids as
	select tl.gid, tl.geom, tlid, gis_acres, prop_code, landuse, yearbuilt
	from taxlots tlS
		left join orca_taxlots ot
		on tl.gid = ot.gid
	--recall that if something is null it won't match any != statements
	where (action_type is null
			or ot.action_type != 'remove')
		and (ot.geom is null
			or (ST_Area(ot.geom) / ST_Area(tl.geom)) < 0.8);