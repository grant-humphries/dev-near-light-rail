--Grant Humphries for TriMet, 2014
--Oracle version: 11.2.0.3
--sqlplus version: 11.2.0.1
----------------------------------

--don't write query results to console
set termout off;
--don't write query stats to console
set feedback off;
--separate columns with commas
set colsep ',';
--don't unserline the header
set underline off;
--trim trailing spaces at the end of a column
set trimspool on;
--width of a page of query results
set linesize 9999;
--height of page of query results
set pagesize 9999;
--number of blank lines at the beginning of page
set newpage none;

--spool writes the results of queries to the file passed to it
spool &1;

--select all permanent max stops using the landmark table, also include each the
--lines that serve each stop as an attribute 
select loc.location_id as stop_id, 
	loc.public_location_description as stop_name,
	':' || listagg(r.route_number, ':; :') within group (order by r.route_number)|| ':' as routes,
	listagg(r.route_description, '; ') within group (order by r.route_description) as route_desc,
	--white space is concatenated to the end of begin date so that the column heading is
	--not truncated, in slqplus the heading can only be as long as the longest value
	min(rs.route_stop_begin_date) || ' ' as begin_date,
	max(rs.route_stop_end_date) as end_date,
	loc.x_coordinate as x_coord, 
	loc.y_coordinate as y_coord
from trans.route_def r, trans.route_stop_def rs, trans.location loc
where loc.location_id = rs.location_id
	and rs.route_stop_end_date > current_date
	and rs.route_number = r.route_number
	and rs.route_begin_date = r.route_begin_date
	and r.route_end_date > current_date
	--route_sub_type '2' is light rail (MAX) 
	and r.route_sub_type = 2
	--'R' routes are 'revenue' routes, meaning that they're open to the public
	and r.route_usage = 'R'
	--to be a 'permanent', a stop must either be in the landmark table or 
	--allow passengers during a service period that end's after today's date
	and (exists (select null from landmark_location ll
					where ll.location_id = loc.location_id
					and exists (select null from landmark lm
								where lm.landmark_id = ll.landmark_id
								and exists (select null from landmark_type lt
											where lt.landmark_id = lm.landmark_id
											and landmark_type = 7)))
		or loc.passenger_access_code != 'N')
	--Some stops may or may not go into service one day are added to the system
	--as place holders and given coordinates of 0, 0
	and loc.x_coordinate != 0
	and loc.y_coordinate != 0
group by loc.location_id, loc.public_location_description,
	loc.x_coordinate, loc.y_coordinate;

spool off;
exit;