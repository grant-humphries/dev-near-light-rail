select distinct l.location_id as stop_id, l.public_location_description as stop_name,
	':MAX Orange Line:' as routes, rs.route_stop_begin_date as begin_date,
	rs.route_stop_end_date as end_date, l.x_coordinate as x_coord, l.y_coordinate as y_coord
from location l, route_stop_def rs
where l.location_id = rs.location_id
and rs.route_number = 290
and l.passenger_access_code <> 'N'
order by l.location_id;