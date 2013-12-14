drop table IF EXISTS streets_and_trails CASCADE;
create table streets_and_trails (
	id serial primary key,
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
	
drop index IF EXISTS node_id_ix CASCADE;
create index node_id_ix on nodes USING BTREE (id);

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

--create indices to speed up matches
drop index IF EXISTS snt_way_id_ix CASCADE;
create index snt_way_id_ix on streets_and_trails USING BTREE (way_id);

drop index IF EXISTS way_tags_k_ix CASCADE;
create index way_tags_k_ix on way_tags USING BTREE (k);

drop index IF EXISTS way_node_seq_id_ix CASCADE;
create index way_node_seq_id_ix on way_nodes USING BTREE (sequence_id);

drop index IF EXISTS seq_count_way_id_ix CASCADE;
create index seq_count_way_id_ix on sequence_count USING BTREE (way_id);

drop index IF EXISTS seq_count_min_ix CASCADE;
create index seq_count_min_ix on sequence_count USING BTREE (seq_min);

drop index IF EXISTS seq_count_max_ix CASCADE;
create index seq_count_max_ix on sequence_count USING BTREE (seq_max);

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