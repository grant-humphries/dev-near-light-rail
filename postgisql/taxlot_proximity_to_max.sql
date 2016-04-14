--This script tabulates which tax lots fall within the supplied
--isochrones and if a tax lot does not fall within an isochrone finds
--the nearest max stop to that tax lot.  These calculations are the
--basis for assigning a 'max group' to each tax lot.  The script also
--checks asto whether each property is in or outside of the urban
--growth boundary, the trimet district and the city limits of the nine
--largest cities in the portland metro area.  It does all this for
--multi-family housing units as well

--1) Taxlots

drop table if exists max_taxlots cascade;
create table max_taxlots (
    id serial primary key,
    gid int references taxlots, 
    geom geometry(MultiPolygon, 2913),
    tlid text,
    totalval numeric,
    gis_acres numeric,
    prop_code text,
    landuse text,
    yearbuilt int,
    max_year int,
    max_zone text,
    near_max boolean,
    walk_dist numeric,
    ugb boolean,
    tm_dist boolean,
    nine_cities boolean
);

vacuum analyze ischrones;

--Spatially join the tax lots and isochrones, note that duplicate geometries
--will exist in this table if a taxlot is within walking distance multiple 
--stops that are in different 'max zones', but duplicates of a properties 
--within the same MAX Zone are eliminated
insert into max_taxlots (
        gid, geom, tlid, totalval, gis_acres, prop_code, landuse, yearbuilt,
        max_year, max_zone, near_max, walk_dist)
    select
        dt.gid, dt.geom, dt.tlid, dt.totalval, dt.gis_acres, dt.prop_code,
        dt.landuse, dt.yearbuilt, min(iso.incpt_year), iso.max_zone, true,
        iso.walk_dist
    from developed_taxlots dt, isochrones iso
    where ST_Intersects(dt.geom, iso.geom)
    group by
        dt.gid, dt.geom, dt.tlid, dt.totalval, dt.gis_acres, dt.prop_code,
        dt.landuse, dt.yearbuilt, iso.max_zone, iso.walk_dist;

--get unique id's of taxlots that are within an ischron
create temp table isochrone_taxlots as
    select distinct gid
    from max_taxlots;

alter table isochrone_taxlots add primary key (gid);
vacuum analyze isochrone_taxlots;

--Find the max zone and max year of the nearest stop to each tax lot, 
--'<->' is the postgis nearest neighbor operator, discussion of this 
--can be found here: http://gis.stackexchange.com/questions/52792
drop table if exists tl_nearest_stop cascade;
create temp table tl_nearest_stop with oids as
    --using an array in subquery of the select clause allows nearest
    --neighbor, which is an expensive operation, to be run once
    select gid, (
        select array[incpt_year::text, max_zone] 
        from max_stops 
        order by geom <-> dt.geom
        limit 1) as year_zone
    from developed_taxlots dt
    where not exists (
        select 1 from isochrone_taxlots
        where gid = dt.gid);

alter table tl_nearest_stop add primary key (gid);
vacuum analyze tl_nearest_stop;

--Insert taxlots that are not within walking distance of max stops into
--max_taxlots 
insert into max_taxlots (
        gid, geom, tlid, totalval, gis_acres, prop_code, landuse, yearbuilt,
        max_year, max_zone, near_max)
    select 
        dt.gid, dt.geom, dt.tlid, dt.totalval, dt.gis_acres, dt.prop_code,
        dt.landuse, dt.yearbuilt, ns.year_zone[1]::int, ns.year_zone[2],
        false
    from developed_taxlots dt, tl_nearest_stop ns
    where dt.gid = ns.gid
        and not exists (
            select 1 from isochrone_taxlots
            where gid = dt.gid);

create index max_taxlot_gix on max_taxlots using GIST (geom);
vacuum analyze max_taxlots;

--Get nine largest portland metro city limits as a single geometry
create temp table nine_cities as
    select ST_Union(geom), 1 as common
    from city
    where cityname in (
        'Portland', 'Gresham', 'Hillsboro', 'Beaverton', 'Tualatin', 
        'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')
    group by common;

create index n_city_gix on nine_cities using GIST (geom);
vacuum analyze nine_cities;

--Determine if taxlots are within trimet district, urban growth boundary,
--and nine largest portland metro city limits
update max_taxlots as mt set
    ugb = (
        select ST_Intersects(ugb.geom, mt.geom)
        from ugb),
    tm_dist = (
        select ST_Intersects(td.geom, mt.geom)
        from tm_district td),
    nine_cities = (
        select ST_Intersects(nc.geom, mt.geom)
        from nine_cities nc);


--2) Multi-Family Housing Units
--Works off the same framework as what is used for tax lots above, note
--that the natural areas don't need to be used as a filtered from these
 --as their property type is known

--Divisors for overall area comparisons will still come from 
--'max_taxlots', but numerators will come from the table below 
--because the multi-family layer doesn't have full coverage of all 
--buildable land in the region

drop table if exists max_multifam cascade;
create table max_multifam (
    id serial primary key,
    gid int references multifamily, 
    geom geometry(MultiPolygon, 2913),
    metro_id int,
    units int,
    unit_type text,
    gis_acres numeric,
    mixed_use int,
    yearbuilt int,
    max_year int,
    max_zone text,
    near_max boolean,
    walk_dist numeric,
    ugb boolean,
    tm_dist boolean,
    nine_cities boolean
);

--the area for multifamily is given in square feet, this is converted
--to acres (43,560 sqft in 1 acre) and stored in 'gis_acres' to be
--congruent with values in the taxlot tables
insert into max_multifam (
        gid, geom, metro_id, units, unit_type, gis_acres, mixed_use, 
        yearbuilt, max_year, max_zone, near_max, walk_dist)
    select 
        mf.gid, mf.geom, mf.metro_id, mf.units, mf.unit_type, 
        (mf.area / 43560), mf.mixed_use, mf.yearbuilt, min(iso.incpt_year), 
        iso.max_zone, true, iso.walk_dist
    from multifamily mf, isochrones iso
    where ST_Intersects(mf.geom, iso.geom)
    group by 
        mf.gid, mf.geom, mf.metro_id, mf.units, mf.yearbuilt, mf.unit_type,
        mf.area, mf.mixed_use, iso.max_zone, iso.walk_dist;

create temp table isochrone_multifam as
    select distinct gid
    from max_multifam;

alter table isochrone_multifam add primary key (gid);
vacuum analyze isochrone_multifam;

create temp table mf_nearest_stop as
    select gid, (
        select array[incpt_year::text, max_zone]
        from max_stops
        order by geom <-> mf.geom
        limit 1) as year_zone
    from multifamily mf
        and not exists (
            select 1 from isochrone_multifam
            where gid = mf.gid);

alter table mf_nearest_stop add primary key (gid);
vacuum analyze mf_nearest_stop;

insert into max_multifam (
        gid, geom, metro_id, units, unit_type, gis_acres, mixed_use, 
        yearbuilt, max_year, max_zone, near_max)
    select 
        mf.gid, mf.geom, mf.metro_id, mf.units, mf.unit_type, 
        (mf.area / 43560), mf.mixed_use, mf.yearbuilt, ns.year_zone[1]::int,
        ns.year_zone[2], false
    from multifamily mf, mf_nearest_stop ns
    where mf.gid = ns.gid
        and not exists (
            select 1 from isochrone_multifam
            where gid = mf.gid);

create index max_multifam_gix on max_multifam using GIST (geom);
vacuum analyze max_multifam;

update max_multifam as mm set
    ugb = (
        select ST_Intersects(ugb.geom, mm.geom)
        from ugb),
    tm_dist = (
        select ST_Intersects(td.geom, mm.geom)
        from tm_district td),
    nine_cities = (
        select ST_Intersects(nc.geom, mm.geom)
        from nine_cities nc);

--ran in ~4,702 seconds on 5/20/14 (definitely benefitted from some
--caching though)