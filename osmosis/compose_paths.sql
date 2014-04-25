drop table if exists streets_and_trails cascade;
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
	surface text, 
	indoor text)
with oids;
	
drop index if exists node_id_ix cascade;
create index node_id_ix on nodes using BTREE (id);

--build the line segments using postgis st_makeline and transform the geometry to oregon
--state plane north projection (2913)
insert into streets_and_trails (geom, way_id)
	select ST_Transform(ST_MakeLine(n.geom order by wn.sequence_id), 2913), wn.way_id
	from nodes n, way_nodes wn
	where n.id = wn.node_id 
	group by wn.way_id;

create temp table sequence_count as
	select way_id, min(sequence_id) as seq_min, max(sequence_id) as seq_max 
	from way_nodes
	group by way_id;

--create indices to speed up matches
drop index if exists snt_way_id_ix cascade;
create index snt_way_id_ix on streets_and_trails using BTREE (way_id);

drop index if exists way_tags_k_ix cascade;
create index way_tags_k_ix on way_tags using BTREE (k);

drop index if exists way_node_seq_id_ix cascade;
create index way_node_seq_id_ix on way_nodes using BTREE (sequence_id);

drop index if exists seq_count_way_id_ix cascade;
create index seq_count_way_id_ix on sequence_count using BTREE (way_id);

drop index if exists seq_count_min_ix cascade;
create index seq_count_min_ix on sequence_count using BTREE (seq_min);

drop index if exists seq_count_max_ix cascade;
create index seq_count_max_ix on sequence_count using BTREE (seq_max);

--add 'to' and 'FROM' node id's
update streets_and_trails as snt set
	from_node = (select wn.node_id from way_nodes wn
		where snt.way_id = wn.way_id 
		and exists (select null from sequence_count sc
						where wn.way_id = sc.way_id
						and wn.sequence_id = sc.seq_min)),

	to_node = (select wn.node_id from way_nodes wn
		where snt.way_id = wn.way_id 
		and exists (select null from sequence_count sc
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
		where snt.way_id = wt.way_id and wt.k = 'surface'),

	indoor = (select wt.v from way_tags wt
		where snt.way_id = wt.way_id and wt.k = 'indoor');

drop table sequence_count;