drop table if exists :web_taxlots cascade;
create table :web_taxlots as
    select
        geom, gid, tlid, totalval, gis_acres, prop_code, landuse, yearbuilt,
        min(max_year) as max_year, near_max, ugb, tm_dist, nine_cities
    from max_taxlots
    group by
        geom, gid, tlid, totalval, gis_acres, prop_code, landuse, yearbuilt,
        near_max, ugb, tm_dist, nine_cities;

create temp table non_park_taxlots as
    select gid
    from :web_taxlots;

alter table non_park_taxlots add primary key (gid);

alter table :web_taxlots add primary key (gid);
alter table :web_taxlots add park boolean default false;

insert into :web_taxlots (geom, gid, park)
    select geom, gid, true
    from taxlots t
    where exists (
        select 1 from orca_taxlots
        where gid = t.gid)
    and not exists (
        select 1 from non_park_taxlots
        where gid = t.gid);