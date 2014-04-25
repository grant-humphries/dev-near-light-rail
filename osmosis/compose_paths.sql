DROP TABLE IF EXISTS streets_and_trails CASCADE;
CREATE TABLE streets_and_trails (
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
WITH OIDS;
	
DROP INDEX IF EXISTS node_id_ix CASCADE;
CREATE INDEX node_id_ix ON nodes USING BTREE (id);

--build the line segments using postgis st_makeline
insert into streets_and_trails (geom, way_id)
	SELECT ST_MakeLine(n.geom order by wn.sequence_id), wn.way_id
	FROM nodes n, way_nodes wn
	WHERE n.id = wn.node_id 
	GROUP BY wn.way_id;

CREATE TEMPORARY TABLE sequence_count AS
	SELECT way_id, min(sequence_id) AS seq_min, max(sequence_id) AS seq_max 
	FROM way_nodes
	GROUP BY way_id;

--create indices to speed up matches
DROP INDEX IF EXISTS snt_way_id_ix CASCADE;
CREATE INDEX snt_way_id_ix ON streets_and_trails USING BTREE (way_id);

DROP INDEX IF EXISTS way_tags_k_ix CASCADE;
CREATE INDEX way_tags_k_ix ON way_tags USING BTREE (k);

DROP INDEX IF EXISTS way_node_seq_id_ix CASCADE;
CREATE INDEX way_node_seq_id_ix ON way_nodes USING BTREE (sequence_id);

DROP INDEX IF EXISTS seq_count_way_id_ix CASCADE;
CREATE INDEX seq_count_way_id_ix ON sequence_count USING BTREE (way_id);

DROP INDEX IF EXISTS seq_count_min_ix CASCADE;
CREATE INDEX seq_count_min_ix ON sequence_count USING BTREE (seq_min);

DROP INDEX IF EXISTS seq_count_max_ix CASCADE;
CREATE INDEX seq_count_max_ix ON sequence_count USING BTREE (seq_max);

--add 'to' AND 'FROM' node id's
update streets_and_trails AS snt set
	from_node = (SELECT wn.node_id FROM way_nodes wn
		WHERE snt.way_id = wn.way_id 
		AND EXISTS (SELECT null FROM sequence_count sc
						WHERE wn.way_id = sc.way_id
						AND wn.sequence_id = sc.seq_min)),

	to_node = (SELECT wn.node_id FROM way_nodes wn
		WHERE snt.way_id = wn.way_id 
		AND EXISTS (SELECT null FROM sequence_count sc
						WHERE wn.way_id = sc.way_id
						AND wn.sequence_id = sc.seq_max)),

	--add the rest of the street/trail attributes
	name = (SELECT wt.v FROM way_tags wt
		WHERE snt.way_id = wt.way_id AND wt.k = 'name'),

	highway = (SELECT wt.v FROM way_tags wt
		WHERE snt.way_id = wt.way_id AND wt.k = 'highway'),

	access = (SELECT wt.v FROM way_tags wt
		WHERE snt.way_id = wt.way_id AND wt.k = 'access'),

	foot = (SELECT wt.v FROM way_tags wt
		WHERE snt.way_id = wt.way_id AND wt.k = 'foot'),

	surface = (SELECT wt.v FROM way_tags wt
		WHERE snt.way_id = wt.way_id AND wt.k = 'surface'),

	indoor = (SELECT wt.v FROM way_tags wt
		WHERE snt.way_id = wt.way_id AND wt.k = 'indoor');

DROP TABLE sequence_count;