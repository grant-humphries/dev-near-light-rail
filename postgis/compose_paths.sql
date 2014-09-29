drop table if exists streets_and_trails cascade;
create table streets_and_trails (
	way_id bigint primary key references ways,
	geom geometry, 
	from_node bigint,
	to_node bigint,
	name text,
	highway text,
	construction text,
	access text,
	foot text,
	surface text, 
	indoor text
);
	
--build the line segments using postgis st_makeline and transform the geometry to oregon
--state plane north projection (2913)
insert into streets_and_trails
	select wn.way_id, ST_Transform(ST_MakeLine(n.geom order by wn.sequence_id), 2913),
		(select node_id from way_nodes where way_id = wn.way_id and sequence_id = min(wn.sequence_id)),
		(select node_id from way_nodes where way_id = wn.way_id and sequence_id = max(wn.sequence_id)),
		w.tags -> 'name', w.tags -> 'highway', w.tags -> 'construction', w.tags -> 'access',
		w.tags -> 'foot', w.tags -> 'surface', w.tags -> 'indoor'
	from nodes n, way_nodes wn, ways w
	where n.id = wn.node_id
		and wn.way_id = w.id
	group by wn.way_id, w.tags;

--for this project we want to route along streets that are under construction if a valid street
--type is indicated in the construction=* tag.  Thus the value in construction will be moved
--to the highway column in those casew when highway=construction
update streets_and_trails set highway = construction, construction = 'yes'
	where highway = 'construction'
		and construction in (select distinct highway from streets_and_trails);