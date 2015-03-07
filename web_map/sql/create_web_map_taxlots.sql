drop table if exists web_map_taxlots cascade;
create table web_map_taxlots as
  select geom, gid, tlid, totalval, gis_acres, prop_code, landuse,
    yearbuilt, min(max_year) as max_year, near_max, ugb, tm_dist, 
    nine_cities
  from analysis_taxlots
  group by geom, gid, tlid, totalval, gis_acres, prop_code, landuse,
    yearbuilt, near_max, ugb, tm_dist, nine_cities;

alter table web_map_taxlots add primary key (gid);
alter table web_map_taxlots add park boolean default false;

insert into web_map_taxlots (geom, gid, park)
  select geom, gid, true
  from taxlots t
  where not exists (
    select 1 from web_map_taxlots w
    where w.gid = t.gid);