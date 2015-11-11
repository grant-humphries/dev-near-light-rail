--Grant Humphries, 2014
--PostGIS Version: 2.1
--PostGreSQL Version: 9.3
---------------------------------

--This script result in a table that contains only tax lots that are less than
--80% covered by natural areas.  This method was developed to replace the technique
--of erasing the geometry of the natural areas from the geometry of the tax lots
--as this left fragments in some case where the datasets didn't perfectly align

--Much of the work here is derived from this post:
--http://gis.stackexchange.com/questions/31310/acquiring-arcgis-like-speed-in-postgis

--Create a table that containing polygons that are the intersection of the
--tax lot and orca datasets, then union any geometries that are derived from 
--same source taxlot
drop table if exists orca_taxlots cascade;
create table orca_taxlots with oids as
	select gid, ST_Multi(ST_Union(geom)) as geom, action_type
	from (select tl.gid, 
			--this case statement prevents taxlots completely within natural areas
			--from having to go through the costly st_intersection step
			case
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
			--this project, those are filtered out below, the excluded categories
			--are 'school lands', 'home owners association lands' and 'other'
			where unittype in ('Cemetery', 'Golf Course', 'Natural Area', 'Park')) o
		--first filtering the data with st_intersects instead of running everything
		--through st_intersection is significantly less expensive
		where ST_Intersects(tl.geom, o.geom)) pre_o_taxlots
	group by gid, action_type;

--Create index to speed up coming matching 
drop index if exists orca_tl_gid_ix cascade;
create index orca_tl_gid_ix on orca_taxlots using BTREE (gid);

drop index if exists orca_tl_gix cascade;
create index orca_tl_gix on orca_taxlots using GIST (geom);

drop index if exists orca_tl_act_type_ix cascade;
create index orca_tl_act_type_ix on orca_taxlots using BTREE (action_type);

drop table if exists taxlots_no_orca cascade;
create table taxlots_no_orca (
	gid int primary key references taxlots, 
	geom geometry,
	tlid text,
	totalval numeric,
	gis_acres numeric,
	prop_code text,
	landuse text,
	yearbuilt int
);

vacuum analyze;

--Now filter out any tax lots that are at least 80% covered by natural areas
insert into taxlots_no_orca
	select tl.gid, tl.geom, tlid, totalval, gis_acres, prop_code, landuse, yearbuilt
	from taxlots tl
		left join orca_taxlots ot
		on tl.gid = ot.gid
	--recall that if something is null it won't match any != statements
	where (ot.action_type != 'remove'
			or action_type is null)
		and (ST_Area(ot.geom) / ST_Area(tl.geom) < 0.8
			or ot.geom is null);

--Create indices to speed the next steps on this analysis, note that gid already
--has a btree index on it thanks to the fact that it is a primary key
drop index if exists taxlots_no_gix cascade;
create index taxlots_no_gix on taxlots_no_orca using GIST (geom);

--Clean-up
vacuum analyze;