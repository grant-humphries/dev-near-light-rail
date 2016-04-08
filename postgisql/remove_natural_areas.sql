--This script results in a table that contains only tax lots that are
--less than 80% covered by natural areas.  This method was developed
--to replace the approach of erasing the geometry of the natural areas
--from the geometry of the tax lots as this left fragments in some case
--where the datasets didn't perfectly align

--The basis of the approach here is derived from this post:
--http://gis.stackexchange.com/questions/31310

drop table if exists orca_taxlots cascade;
with disjoint_orca_taxlots as (
    select
        t.gid,
        --this prevents tax lots completely within natural areas
        --from having to go through the costly st_intersection step
        case
            when ST_Within(t.geom, o.geom) then t.geom
            else ST_Multi(ST_Intersection(t.geom, o.geom))
        end as geom,
        case
            when ST_Within(t.geom, o.geom) then 'drop'
            else 'compare'
        end as action_type
    from taxlots t, orca o
    --first filtering with st_intersects instead of running everything
    --through st_intersection is significantly less expensive
    where ST_Intersects(t.geom, o.geom)
        --only the following orca types are considered natural areas
        --for the purposes of this project
        and o.unitype in ('Cemetery', 'Golf Course', 'Natural Area', 'Park'))
--tax lots can be split into pieces if multiple orca areas overlap them
--this part of the query reunifies them
create table orca_taxlots as
    select gid, ST_Multi(ST_Union(geom)) as geom, action_type
    from disjoint_orca_taxlots
    group by gid, action_type;

alter table orca_taxlots add primary key (gid);
create index otl_gix on orca_taxlots using GIST (geom);
create index otl_act_type_ix on orca_taxlots using BTREE (action_type);
vacuum analyze orca_taxlots;


drop table if exists developed_taxlots cascade;
create table developed_taxlots (
    gid int primary key references taxlots,
    geom geometry,
    tlid text,
    totalval numeric,
    gis_acres numeric,
    prop_code text,
    landuse text,
    yearbuilt int
);

--filter out any tax lots that are at least 80% covered by natural areas
insert into developed_taxlots
    select
        tl.gid, tl.geom, tlid, totalval, gis_acres,
        prop_code, landuse, yearbuilt
    from taxlots tl
        left join orca_taxlots ot
            on tl.gid = ot.gid
    --recall that if something is null it won't match any != statements
    where (
        ot.action_type = 'compare'
            and ST_Area(ot.geom) / ST_Area(tl.geom) < 0.8)
        or ot.action_type is null
        or ot.geom is null;

create index dev_taxlots_gix on developed_taxlots using GIST (geom);
vacuum analyze developed_taxlots;