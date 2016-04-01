import numbers
import sys
from argparse import ArgumentParser
from collections import OrderedDict
from datetime import date
from os.path import join

import fiona
from fiona.crs import from_epsg
from shapely.geometry import mapping, Point
from sqlalchemy import create_engine, func, or_
from sqlalchemy.orm import aliased, sessionmaker

from trimet.model.oracle.trans import Location, RouteDef, RouteStopDef, \
    Landmark, LandmarkLocation, LandmarkType

RLIS_DIR = '//gisstore/gis/Rlis'
TAXLOTS = join(RLIS_DIR, 'TAXLOT', 'taxlots.shp')
date_dir =

HOME = '//gisstore/gis/PUBLIC/GIS_Projects/Development_Around_Lightrail'
STOPS_SHP = join(HOME, 'data', 'max_stops.shp')


def get_permanent_max_stops():
    """"""

    oracle_url = 'oracle://{user}:{password}@{db}'.format(
        user=gv.user, password=gv.password, db=gv.dbname)
    engine = create_engine(oracle_url)
    sess_maker = sessionmaker(bind=engine)
    session = sess_maker()

    # these are aliased to abbreviations as they're used repeatedly
    loc = aliased(Location)
    rd = aliased(RouteDef)
    rsd = aliased(RouteStopDef)
    lm = aliased(Landmark)
    lml = aliased(LandmarkLocation)
    lmt = aliased(LandmarkType)

    today = date.today()
    date_format = 'DD-MON-YY'

    # the following form a nested 'where exists' subquery that ensures
    # that a location exists as a platform (landmark_type=7)
    sub1 = (
        session.query(lmt).
        filter(lmt.landmark_type == 7,
               lmt.landmark_id == lm.landmark_id)
    )
    sub2 = (
        session.query(lm).
        filter(lm.landmark_id == lml.landmark_id,
               sub1.exists())
    )
    sub3 = (
        session.query(lml).
        filter(lml.location_id == loc.location_id,
               sub2.exists())
    )

    # this query contains checks to ensure all permanent max stops are
    # grabbed as sometimes they're shutdown temporarily
    max_stops = (
        session.query(
            loc.location_id.label('stop_id'),
            loc.public_location_description.label('stop_name'),
            func.collect(rd.route_number.distinct()).label('routes'),
            func.collect(
                rd.public_route_description.distinct()).label('route_desc'),
            func.to_char(
                func.min(rsd.route_stop_begin_date),
                date_format).label('begin_date'),
            func.to_char(
                func.max(rsd.route_stop_end_date),
                date_format).label('end_date'),
            loc.x_coordinate.label('x_coord'),
            loc.y_coordinate.label('y_coord')).
        filter(
            loc.location_id == rsd.location_id,
            rd.route_number == rsd.route_number,
            rd.route_begin_date == rsd.route_begin_date,
            rd.route_end_date > today,
            rd.is_light_rail,
            rd.is_revenue,
            rsd.route_stop_end_date > today,
            or_(sub3.exists(),
                loc.passenger_access_code != 'N'),
            # Some stops may or may not go into service one day are
            # added to the system as place holders and given
            # coordinates of 0, 0
            loc.x_coordinate != 0,
            loc.y_coordinate != 0).
        group_by(
            loc.location_id,
            loc.public_location_description,
            loc.x_coordinate,
            loc.y_coordinate).
        all()
    )

    return max_stops


def write_stops_to_shapefile():
    """"""

    max_stops = get_permanent_max_stops()

    # convert query results into format suitable for insert
    features = list()
    for row in max_stops:
        attributes = OrderedDict(zip(row.keys(), row))

        x = attributes.pop('x_coord')
        y = attributes.pop('y_coord')
        geom = Point(x, y)

        for k, v in attributes.items():
            if isinstance(v, list):
                if isinstance(v[0], numbers.Number):
                    str_list = sorted([str(int(i)) for i in v])
                    v = ':{}:'.format(':; :'.join(str_list))
                else:
                    v = '; '.join(sorted(v))
            elif isinstance(v, unicode):
                v = str(v)

            attributes[k] = v

        features.append({
            'geometry': mapping(geom),
            'properties': attributes
        })

    # create metadata object for shapefile
    sample_feat = features[0]['properties'].items()
    fields = OrderedDict([(k, type(v).__name__) for k, v in sample_feat])

    metadata = {
        'crs': from_epsg(2913),
        'driver': 'ESRI Shapefile',
        'schema': {
            'geometry': 'Point',
            'properties': fields
        }
    }

    with fiona.open(STOPS_SHP, 'w', **metadata) as stops_shp:
        for feat in features:
            stops_shp.write(feat)


def process_oracle_options(arglist=None):
    """"""

    parser = ArgumentParser()
    parser.add_argument(
        '-u', '--user',
        required=True,
        help='oracle user name'
    )
    parser.add_argument(
        '-d', '--dbname',
        required=True,
        help='name of target oracle database'
    )
    parser.add_argument(
        '-p', '--password',
        required=True,
        help='oracle password for supplied user'
    )

    options = parser.parse_args(arglist)
    return options


def main():
    """"""

    # As of 4/2016 there are 166 permanent MAX stops

    global gv
    args = sys.argv[1:]
    gv = process_oracle_options(args)

    write_stops_to_shapefile()


if __name__ == '__main__':
    main()
