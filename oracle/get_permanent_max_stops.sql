--set term off
--set feedback off
set colsep ','
set underline off
set trimspool on
set linesize 9999
set pagesize 9999
set newpage none

spool &1

select loc.location_id as stop_id, 
	loc.public_location_description as stop_name,
	':' || listagg(r.route_number, ':;:') within group (order by r.route_number)|| ':' as routes,
	listagg(r.route_description, ';') within group (order by r.route_description) as route_desc,
	min(rs.route_stop_begin_date) as begin_date,
	max(rs.route_stop_end_date) as end_date,
	loc.x_coordinate as x_coord, 
	loc.y_coordinate as y_coord
from route_def r, route_stop_def rs, location loc
where loc.location_id = rs.location_id
	and rs.route_number = r.route_number
	and rs.route_begin_date = r.route_begin_date
	and r.route_end_date > current_date
	--route_sub_type to in this case is MAX (as opposed to WES or other rail)
	and r.route_sub_type = 2
	--'R' routes are 'revenue' routes, meaning that they're open to the public
	and r.route_usage = 'R'
	--Some stops may or may not go into service one day are added to the system
	--as place holders and given coordinates of 0, 0
	and loc.x_coordinate != 0
	and loc.y_coordinate != 0
	and exists (select null from landmark_location ll
				where ll.location_id = loc.location_id
				and exists (select null from landmark lm
							where lm.landmark_id = ll.landmark_id
							and exists (select null from landmark_type lt
										where lt.landmark_id = lm.landmark_id
										and landmark_type = 7)))
group by loc.location_id, loc.public_location_description,
	loc.x_coordinate, loc.y_coordinate;

spool off;
exit;