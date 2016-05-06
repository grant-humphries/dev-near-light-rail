import sys
from argparse import ArgumentParser
from collections import OrderedDict
from datetime import datetime
from functools import partial

import fiona
import overpass
import pyproj
from fiona.crs import from_epsg
from shapely import ops
from shapely.geometry import mapping, shape

from lightraildev.common import OSM_PED_SHP


def overpass2shp():
    """"""

    api = overpass.API()
    overpass_query = 'way["highway"~"{values}"]({bbox})'
    values = '|'.join(gv.highway_filter)
    bbox = ','.join(str(c) for c in gv.bounding_box.values())

    response = api.Get(overpass_query.format(values=values, bbox=bbox))
    features = response['features']

    meta_fields = OrderedDict([(k, 'str') for k in gv.attribute_keys])
    metadata = {
        'crs': from_epsg(gv.epsg),
        'driver': 'ESRI Shapefile',
        'schema': {
            'geometry': 'LineString',
            'properties': meta_fields
        }
    }

    reproject = True if gv.epsg != gv.wgs84 else False
    if reproject:
        transformation = partial(
            pyproj.transform,
            pyproj.Proj(init='epsg:{}'.format(gv.wgs84)),
            pyproj.Proj(init='epsg:{}'.format(gv.epsg), preserve_units=True)
        )

    with fiona.open(OSM_PED_SHP, 'w', **metadata) as osm_shp:
        for feat in features:
            fields = feat['properties']
            write_fields = {k: None for k in gv.attribute_keys}
            for k, v in fields.items():
                if k in gv.attribute_keys:
                    write_fields[k] = v

            feat['properties'] = write_fields

            if reproject:
                geom = shape(feat['geometry'])
                new_geom = ops.transform(transformation, geom)
                feat['geometry'] = mapping(new_geom)

            osm_shp.write(feat)


def process_options(args):
    """"""

    wgs84, ospn = 4326, 2913
    bbox_order = ('min_lat', 'min_lon', 'max_lat', 'max_lon')
    bounding_box = (45.2, -123.2, 45.7, -122.2)

    # due to the structure of the overpass query 'link's will be returned
    # for any base type that is supplied to 'trunk', will return both ways
    # tagged with 'trunk' and 'trunk_link' for instance
    highway_values = (
        'bridleway', 'construction', 'cycleway', 'footway', 'motorway',
        'path', 'pedestrian', 'primary', 'road', 'residential', 'secondary',
        'service', 'steps', 'tertiary', 'track', 'trunk', 'unclassified'
    )
    attribute_keys = (
        'access', 'foot', 'highway', 'indoor', 'maxspeed', 'name', 'oneway',
        'ref', 'surface'
    )

    parser = ArgumentParser()
    parser.add_argument(
        '-a', '--attribute_keys',
        default=attribute_keys,
        nargs='+',
        help='osm tag keys that will be retained as attributes on the '
             'resultant shapefile, enter space separated'
    )
    parser.add_argument(
        '-b', '--bounding_box',
        default=bounding_box,
        nargs=4,
        type=float,
        help='bounding box for which osm data will be download should be'
             'entered space separated in the following order: min_lat, '
             'min_lon, max_lat, max_lot'
    )
    parser.add_argument(
        '-t', '--transform',
        default=ospn,
        dest='epsg',
        type=int,
        help='data will be transformed to the spatial reference system '
             'represented by the supplied epsg code, the data is downloaded '
             'as {s_srs} and transformed to {d_srs} by default'.format(
                 s_srs=wgs84, d_srs=ospn)
    )
    parser.add_argument(
        '-f', '--highway_filter',
        default=highway_values,
        nargs='+',
        help='values supplied to this parameter will be paired with the key '
             '"highway" to create tags, if a way has any of the resultant tags '
             '(and is within the bounding box) it will be downloaded, enter'
             'values space separated'
    )

    parser.set_defaults(wgs84=wgs84)
    options = parser.parse_args(args)
    options.bounding_box = OrderedDict(zip(bbox_order, bounding_box))
    return options


def main():
    """"""

    start_time = datetime.now().strftime('%I:%M %p')
    print '2) Fetching OSM data and converting to shapefile, start time ' \
          'is: {}, run time is: ~3.5 minutes...\n'.format(start_time)

    global gv
    args = sys.argv[1:]
    gv = process_options(args)

    overpass2shp()


if __name__ == '__main__':
    main()
