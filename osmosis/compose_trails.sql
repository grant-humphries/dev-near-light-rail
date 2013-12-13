drop table IF EXISTS streets_and_trails CASCADE;
create table streets_and_trails (
	geom geometry, 
	way_id bigint,
	from_node bigint,
	to_node bigint,
	name text,
	highway text,
	access text,
	foot text,
	surface text
);
	
--build the line segments using postgis st_makeline
insert into streets_and_trails (geom, way_id)
	select ST_MakeLine(n.geom order by wn.sequence_id), wn.way_id
	from nodes n, way_nodes wn
	where n.id = wn.node_id 
	group by wn.way_id;

CREATE TEMPORARY TABLE sequence_count as
	select way_id, min(sequence_id) as seq_min, max(sequence_id) as seq_max 
	from way_nodes
	group by way_id;

--add 'to' and 'from' node id's
update streets_and_trails as snt set
	from_node = (select wn.node_id from way_nodes wn
		where snt.way_id = wn.way_id 
		and EXISTS (select null from sequence_count sc
						where wn.way_id = sc.way_id
						and wn.sequence_id = sc.seq_min)),

	to_node = (select wn.node_id from way_nodes wn
		where snt.way_id = wn.way_id 
		and EXISTS (select null from sequence_count sc
						where wn.way_id = sc.way_id
						and wn.sequence_id = sc.seq_max)),

	--add the rest of the street/trail attributes
	name = (select wt.v from way_tags wt
		where snt.way_id = wt.way_id and wt.k = 'name'),

	highway = (select wt.v from way_tags wt
		where snt.way_id = wt.way_id and wt.k = 'highway'),

	access = (select wt.v from way_tags wt
		where snt.way_id = wt.way_id and wt.k = 'access'),

	foot = (select wt.v from way_tags wt
		where snt.way_id = wt.way_id and wt.k = 'foot'),

	surface = (select wt.v from way_tags wt
		where snt.way_id = wt.way_id and wt.k = 'surface');

drop table sequence_count;