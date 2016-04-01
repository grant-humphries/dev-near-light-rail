import sys
from argparse import ArgumentParser
from datetime import date
from os.path import abspath, dirname

from sqlalchemy import create_engine, func, or_
from sqlalchemy.orm import aliased, sessionmaker

from trimet.model.oracle.trans import Location, RouteDef, RouteStopDef, \
    Landmark, LandmarkLocation, LandmarkType

HOME = dirname(abspath(sys.argv[0]))


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
            func.listagg(rd.route_number).label('routes'),
            func.min(rsd.route_stop_begin_date).label('begin_date'),
            func.max(rsd.route_stop_end_date).label('end_date'),
            loc.x_coordinate.label('x_coord'),
            loc.y_coordinate.label('y_coord')).
        filter(
            loc.location_id == rsd.location_id,
            rd.route_number == rsd.route_number,
            rd.route_begin_date == rsd.route_begin_date,
            rd.route_end_date < today,
            rd.is_light_rail,
            rd.is_revenue,
            rsd.route_stop_end_date < today,
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

    for row in max_stops:
        print row
        exit()


def write_stops_to_shapefile():
    """"""

    pass


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

    global gv
    args = sys.argv[1:]
    gv = process_oracle_options(args)

    get_permanent_max_stops()


if __name__ == '__main__':
    main()
