--This script tabulates the intersection of tax lots and isochrones and finds
--the nearest max stop to any tax lot that don't touch an isochrone.  These
--calculations are the basis for assigning a 'max group' to each tax lot.  The
--script also checks as to whether each property is in or outside of the urban
--growth boundary, the trimet district and the city limits of the nine largest
--cities in the portland metro area.  It does all this for multi-family
--housing units as well

--Get nine largest portland metro city limits as a single geometry
create temp table nine_cities as
    select ST_Union(geom) as geom, 1 as common
    from city
    where cityname in (
        'Portland', 'Gresham', 'Hillsboro', 'Beaverton', 'Tualatin',
        'Tigard', 'Lake Oswego', 'Oregon City', 'West Linn')
    group by common;

create index n_city_gix on nine_cities using GIST (geom);
vacuum analyze nine_cities;


--1) Taxlots

--Determine if taxlots are within trimet district, urban growth boundary,
--and nine largest portland metro city limits

alter table developed_taxlots
    drop if exists nine_cities,
    drop if exists tm_dist,
    drop if exists ugb;
alter table developed_taxlots
    add nine_cities boolean,
    add tm_dist boolean,
    add ugb boolean;

update developed_taxlots as dt set
    ugb = (
        select ST_Intersects(ST_Envelope(dt.geom), geom)
        from ugb),
    tm_dist = (
        select ST_Intersects(ST_Envelope(dt.geom), geom)
        from tm_district),
    nine_cities = (
        select ST_Intersects(ST_Envelope(dt.geom), geom)
        from nine_cities);

drop table if exists max_taxlots cascade;
create table max_taxlots (
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
    walk_dist numeric,
    near_max boolean,
    nine_cities boolean,
    tm_dist boolean,
    ugb boolean,
    primary key (gid, max_zone)
);

vacuum analyze developed_taxlots;
vacuum analyze isochrones;

--Duplicate geometries will exist in this table if a taxlot is within
--walking distance multiple stops that are in different 'max zones',
--but duplicates of properties within the same MAX Zone are eliminated
insert into max_taxlots
    select
        dt.gid, dt.geom, dt.tlid, dt.totalval, dt.gis_acres, dt.prop_code,
        dt.landuse, dt.yearbuilt, min(iso.incpt_year), iso.max_zone,
        iso.walk_dist, true, dt.nine_cities, dt.tm_dist, dt.ugb
    from developed_taxlots dt, isochrones iso
    where ST_Intersects(dt.geom, iso.geom)
    group by
        dt.gid, dt.geom, dt.tlid, dt.totalval, dt.gis_acres, dt.prop_code,
        dt.landuse, dt.yearbuilt, iso.max_zone, iso.walk_dist, dt.nine_cities,
        dt.tm_dist, dt.ugb;

--get unique id's of taxlots that are within an ischron
create temp table isochrone_taxlots as
    select distinct gid
    from max_taxlots;

alter table isochrone_taxlots add primary key (gid);
vacuum analyze isochrone_taxlots;

--Find the max zone and max year of the nearest stop to each tax lot,
--'<->' is the postgis nearest neighbor operator, discussion of this
--can be found here: http://gis.stackexchange.com/questions/52792
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
insert into max_taxlots
    select
        dt.gid, dt.geom, dt.tlid, dt.totalval, dt.gis_acres, dt.prop_code,
        dt.landuse, dt.yearbuilt, ns.year_zone[1]::int, ns.year_zone[2],
        null, false, dt.nine_cities, dt.tm_district, dt.ugb
    from developed_taxlots dt, tl_nearest_stop ns
    where dt.gid = ns.gid
        and not exists (
            select 1 from isochrone_taxlots
            where gid = dt.gid);

create index max_taxlot_gix on max_taxlots using GIST (geom);
vacuum analyze max_taxlots;


--2) Multi-Family Housing Units

--Works off the same framework as what is used for tax lots above, natural
--areas don't need to be used as a filtered from these as their property type
 --is known

--Divisors for overall area comparisons will still come from 'max_taxlots',
--but numerators will come from the table below because the multifamily layer
--doesn't have full coverage of all buildable land in the region

--filter out any units that are in the project area of interest while
--getting the units proximity to boundaries
create temp table filtered_multifam as
    select
        gid, geom, metro_id, units, unit_type, area, mixed_use, yearbuilt,
        (select ST_Intersects(ST_Envelope(mf.geom), geom)
             from nine_cities) as nine_cities,
        (select ST_Intersects(ST_Envelope(mf.geom), geom)
             from tm_district) as tm_dist,
        (select ST_Intersects(ST_Envelope(mf.geom), geom)
             from ugb) as ugb
    from multifamily mf
    where exists (
            select 1 from tm_district
            where ST_Intersects(ST_Envelope(mf.geom), geom))
        or exists (
            select 1 from ugb
            where ST_Intersects(ST_Envelope(mf.geom), geom));

alter table filtered_multifam add primary key (gid);
create index filtered_mf_gix on filtered_multifam using GIST (geom);
vacuum analyze filtered_multifam;

drop table if exists max_multifam cascade;
create table max_multifam (
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
    walk_dist numeric,
    near_max boolean,
    nine_cities boolean,
    tm_dist boolean,
    ugb boolean,
    primary key (gid, max_zone)
);

--the area for multifamily is given in square feet, this is converted
--to acres (43,560 sqft in 1 acre) and stored in 'gis_acres' to be
--congruent with values in the taxlot tables
insert into max_multifam
    select 
        fm.gid, fm.geom, fm.metro_id, fm.units, fm.unit_type,
        (fm.area / 43560), fm.mixed_use, fm.yearbuilt, min(iso.incpt_year),
        iso.max_zone, iso.walk_dist, true, fm.nine_cities, fm.tm_dist, fm.ugb
    from filtered_multifam fm, isochrones iso
    where ST_Intersects(fm.geom, iso.geom)
    group by 
        fm.gid, fm.geom, fm.metro_id, fm.units, fm.yearbuilt, fm.unit_type,
        fm.area, fm.mixed_use, iso.max_zone, iso.walk_dist, fm.nine_cities,
        fm.tm_dist, fm.ugb;

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
    where not exists (
        select 1 from isochrone_multifam
        where gid = mf.gid);

alter table mf_nearest_stop add primary key (gid);
vacuum analyze mf_nearest_stop;

insert into max_multifam
    select 
        fm.gid, fm.geom, fm.metro_id, fm.units, fm.unit_type,
        (fm.area / 43560), fm.mixed_use, fm.yearbuilt, ns.year_zone[1]::int,
        ns.year_zone[2], null, false, fm.nine_cities, fm.tm_dist, fm.ugb
    from filtered_multifam fm, mf_nearest_stop ns
    where fm.gid = ns.gid
        and not exists (
            select 1 from isochrone_multifam
            where gid = fm.gid);

create index max_multifam_gix on max_multifam using GIST (geom);
vacuum analyze max_multifam;
