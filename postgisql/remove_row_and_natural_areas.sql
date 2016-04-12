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
    select
        gid, ST_MakeValid(geom), tlid, totalval, gis_acres, prop_code,
        landuse, yearbuilt
    from taxlots
    where tlid !~ 'RIV$|STR$|RR$|BPA$|RAIL|RLRD$|ROADS$|WATER$|RW$|COM$|NA$';

create index dev_taxlots_gix on developed_taxlots using GIST (geom);
vacuum analyze developed_taxlots;


--The basis of the approach below is derived from this post:
--http://gis.stackexchange.com/questions/31310

drop index if exists orca_type_ix cascade;
create index orca_type_ix on orca using BTREE (unittype);
vacuum analyze orca;

drop table if exists orca_taxlots cascade;
create table orca_taxlots as
    with orca_taxlots_fragments as (
        select
            dt.gid,
            --this prevents tax lots completely within natural areas
            --from having to go through the costly st_intersection step
            case
                when ST_Within(dt.geom, o.geom) then dt.geom
                else ST_Multi(ST_Intersection(dt.geom, ST_MakeValid(o.geom)))
            end as geom,
            case
                when ST_Within(dt.geom, o.geom) then 'drop'
                else 'compare'
            end as action_type
        from developed_taxlots dt, orca o
        --first filtering with st_intersects instead of running
        --everything through st_intersection is significantly less
        --expensive
        where ST_Intersects(dt.geom, o.geom)
            --only the following orca types are considered natural
            --areas for the purposes of this project
            and o.unittype in ('Cemetery', 'Golf Course',
                               'Natural Area', 'Park'))
    --tax lots can be split into pieces if multiple orca areas overlap
    --them this part of the query reunifies them
    select gid, ST_Multi(ST_Union(geom)) as geom, action_type
    from orca_taxlots_fragments
    group by gid, action_type;

alter table orca_taxlots add primary key (gid);
create index otl_gix on orca_taxlots using GIST (geom);
create index otl_act_type_ix on orca_taxlots using BTREE (action_type);
vacuum analyze orca_taxlots;

--filter out any tax lots that are at least 80% covered by natural areas
delete from developed_taxlots dt
using orca_taxlots ot
where dt.gid = ot.gid
    and (ot.action_type = 'drop'
         or (ot.action_type = 'compare'
             and ST_Area(ot.geom) / ST_Area(tl.geom) > 0.8));


create index dev_taxlots_gix on developed_taxlots using GIST (geom);
vacuum analyze developed_taxlots;