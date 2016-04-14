--This script results in a table that contains only tax lots that are
--less than 80% covered by natural areas and that are not in street
--right-of-way or areas that are submerged in water.  This method was
--developed to replace the approach of erasing the geometry of the
--natural areas from the geometry of the tax lots as this left
--fragments in some case where the datasets didn't perfectly align

drop table if exists developed_taxlots cascade;
create table developed_taxlots (
    gid int primary key references taxlots,
    geom geometry(MultiPolygon, 2913),
    tlid text,
    totalval numeric,
    gis_acres numeric,
    prop_code text,
    landuse text,
    yearbuilt int
);

--select only tax lots that are *not* right-of-way or river, ST_MakeValid
--fixes self intersecting rings in the taxlots
insert into developed_taxlots
    --the bounding box that exists around the trimet district and the
    --ugb defines the area of interest for this project
    with boundaries (geom, name) as (
        select geom, 'ugb'
        from ugb
            union
        select geom, 'trimet district'
        from tm_district),
    b_box as (
        select ST_SetSRID(ST_Extent(geom), 2913) as geom
        from boundaries)
    select
        gid, ST_MakeValid(geom), tlid, totalval, gis_acres, prop_code,
        landuse, yearbuilt
    from taxlots t
    where tlid !~ 'RIV$|STR$|RR$|BPA$|RAIL|RLRD$|ROADS$|WATER$|RW$|COM$|NA$'
        and exists (
            select 1 from b_box b
            where t.geom && b.geom);

create index dev_taxlots_gix on developed_taxlots using GIST (geom);
vacuum analyze developed_taxlots;

--The basis of the approach below is derived from this post:
--http://gis.stackexchange.com/questions/31310

drop index if exists orca_type_ix cascade;
create index orca_type_ix on orca_sites using BTREE (type);
vacuum analyze orca_sites;

drop table if exists orca_dissolve cascade;
create table orca_dissolve as
    with orca_union as (
        select ST_Union(ST_MakeValid(geom)) as geom, type
        from orca_sites
        --the following orca types cover areas that should be excluded
        --from this analysis
        where type in ('Cemetery', 'Golf Course', 'Park and/or Natural Area')
        group by type)
    select (ST_Dump(geom)).geom as geom, type
    from orca_union;

alter table orca_dissolve add gid serial primary key;
create index orca_dslv_gix on orca_dissolve using GIST (geom);
vacuum analyze orca_dissolve;

--with a small buffer created around the natural area many more of the
--tax lots are completely contained by the natural areas which means
--fewer time consuming st_intersections below, if the tax lot is that
--close to being contained it should be dropped
create temp table orca_buffers as
    select gid, ST_Buffer(geom, 1) as geom
    from orca_dissolve;

create index orca_buff_gix on orca_buffers using GIST (geom);
vacuum analyze orca_buffers;

drop table if exists orca_taxlots cascade;
create table orca_taxlots (
    gid int primary key references taxlots,
    geom geometry(MultiPolygon, 2913),
    action_type text
);

insert into orca_taxlots
    with overlap as (
        --case 1 prevents tax lots completely within natural areas from
        --having to go through the costly st_intersection step
        select
            t.gid,
            case
                when ST_Within(t.geom, b.geom) then t.geom
                else ST_Intersection(t.geom, d.geom)
            end as geom,
            case
                when ST_Within(t.geom, b.geom) then 'drop'
                else 'compare'
            end as action_type
        from developed_taxlots t, orca_dissolve d, orca_buffers b
        --first filtering with st_intersects instead of running
        --everything through st_intersection is much less expensive
        --(I've tried adding `not st_touches(t.geom, d.geom)` and it
        --slows things down)
        where ST_Intersects(t.geom, d.geom)
            and d.gid = b.gid),
    --st_intersection creates a variety geometry types including
    --collections which need to be unpacked
    dump as (
        select gid, (ST_Dump(geom)).geom as geom, action_type
        from overlap)
    --all geometries that aren't polygons won't cover a meaningful
    --portion of a tax lot and should be discarded
    select
        gid, ST_Multi(ST_Union(geom)) as geom,
        max(action_type) as action_type
    from dump
    where GeometryType(geom) ilike 'Polygon'
    group by gid;

create index otl_gix on orca_taxlots using GIST (geom);
create index otl_act_type_ix on orca_taxlots using BTREE (action_type);
vacuum analyze orca_taxlots;

--filter out any tax lots that are at least 80% covered by natural areas
delete from developed_taxlots dt
using orca_taxlots ot
where dt.gid = ot.gid
    and (ot.action_type = 'drop'
         or (ot.action_type = 'compare'
             and ST_Area(ot.geom) / ST_Area(dt.geom) > 0.8));

vacuum analyze developed_taxlots;