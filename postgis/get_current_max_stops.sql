drop table if exists max_stops cascade;
create table max_stops with oids as
	select geom, id as stop_id, name as stop_name, routes, begin_date, end_date
	from current.stop_ext
	--filter out stops not currently in operation
	where current_date between begin_date and end_date
		--'type' 5 is MAX stops
		and type = 5;