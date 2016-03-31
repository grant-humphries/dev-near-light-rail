import sys
from argparse import ArgumentParser
from datetime import date
from os.path import abspath, dirname

from sqlalchemy import create_engine, func
from sqlalchemy.orm import aliased, sessionmaker

from trimet.model.oracle.trans import Location, RouteDef, RouteStopDef, \
    Landmark, LandmarkLocation, LandmarkType

HOME = dirname(abspath(sys.argv[0]))


def get_permanent_max_stops():
    """"""

    pg_url = 'postgresql://{user}:{password}@{host}/{db}'.format(
        user=gv.user, password=gv.password, host=gv.host, db=gv.dbname)
    engine = create_engine(pg_url)
    session_maker = sessionmaker(bind=engine)
    session = session_maker()

    session.

    loc = aliased(Location)
    rd = aliased(RouteDef)
    rsd = aliased(RouteStopDef)
    lm = aliased(Landmark)
    lml = aliased(LandmarkLocation)
    lmt = aliased(LandmarkType)

    today = date.today()

    max_stops = (
        session.query(
            loc.location_id.label('stop_id'),
            func.min(rsd.route_stop_begin_date).label('begin_date'),
            func.max(rsd.route_stop_end_date).label('end_date'),
            loc.x_coordinate.label('x_coord'),
            loc.y_coordinate.label('y_coord')).
        filter(
            loc.x_coordinate != 0,
            loc.
            rd.route_end_date < today,
            rd.is_light_rail,
            rd.is_revenue,
            rsd.route_stop_end_date < today).
        group_by(
            loc.location_id,
            loc.public_location_description,
            loc.x_coordinate,
            loc.y_coordinate)
    )


def write_stops_to_shapefile():
    """"""

    pass


def process_postgres_options(arglist=None):
    """"""

    # if the PGPASSWORD environment variable has been set use it
    password = os.environ.get('PGPASSWORD')
    if password:
        pw_require = False
    else:
        pw_require = True

    parser = ArgumentParser()
    parser.add_argument(
        '-H', '--host',
        default='localhost',
        help='url of postgres host server'
    )
    parser.add_argument(
        '-u', '--user',
        default='postgres',
        help='postgres user name'
    )
    parser.add_argument(
        '-d', '--dbname',
        default='postgres',
        help='name of target database'
    )
    parser.add_argument(
        '-p', '--password',
        required=pw_require,
        default=password,
        help='postgres password for supplied user, if PGPASSWORD environment'
             'variable is set it will be read from that setting'
    )

    options = parser.parse_args(arglist)
    return options


def main():
    """"""

    global gv
    args = sys.argv[1:]
    gv = process_postgres_options(args)

    get_permanent_max_stops()


if __name__ == '__main__':
    main()
