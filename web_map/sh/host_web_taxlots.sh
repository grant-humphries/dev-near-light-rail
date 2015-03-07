# !/bin/sh

# Set localhost postgres parameters
lh_host=localhost
lh_user=postgres
lh_dbname=transit_dev

echo "Enter PostGreSQL password for host=${lh_host} user=${lh_user}:"
read -s lh_password

# Set maps7 postgres parameters
m7_host=maps7.trimet.org
m7_user=geoserve
m7_schema=misc_gis
m7_dbname=trimet

echo "Enter PostGreSQL password for host=${m7_host} user=${m7_user}:"
read -s m7_password

# Assign other project variables
proj_dir="G:/PUBLIC/GIS_Projects/Development_Around_Lightrail"
code_dir="${proj_dir}/github/dev-near-lightrail/web_map"
data_dir="${proj_dir}/web_map/shp"
shp="${data_dir}/${lh_table}.shp"
table=web_map_taxlots

createWebMapTaxlots()
{
	web_tl_script="${code_dir}/sql/create_web_map_taxlots.sql"
	echo "psql -w -h $lh_host -U $lh_user -d $lh_dbname -f $web_tl_script"
	psql -w -h $lh_host -U $lh_user -d $lh_dbname -f "$web_tl_script"
}

exportWebTaxlotsToShp()
{
	echo "pgsql2shp -k -h $lh_host -u $lh_user \
		-P $lh_password -f $shp $lh_dbname $table"
	pgsql2shp -k -h $lh_host -u $lh_user \
		-P $lh_password -f $shp $lh_dbname $table
}

loadToPgServer()
{
	shp_epsg=2913
	echo "shp2pgsql -d -s $shp_epsg -D -I $shp ${m7_schema}.${table} \
		| psql -q -h $m7_host -U $m7_user -d $m7_dbname"
	shp2pgsql -d -s $shp_epsg -D -I $shp ${m7_schema}.${table} \
		| psql -q -h $m7_host -U $m7_user -d $m7_dbname
}

createWebMapTaxlots;
exportWebTaxlotsToShp;
loadToPgServer;