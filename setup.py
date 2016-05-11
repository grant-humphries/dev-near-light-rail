from setuptools import find_packages, setup

setup(
    name='lightraildev',
    version='0.3.0',
    author='Grant Humphries',
    dependency_links=['http://dev.trimet.org/pypi/dist/'],
    description='',
    entry_points={
        'console_scripts': [
            'create_isochrones = lightraildev.create_isochrones:main',
            'create_network = lightraildev.create_network_dataset:main',
            'csv_to_excel = lightraildev.convert_csv_to_excel:main',
            'get_max_stops = lightraildev.get_permanent_max_stops:main',
            'osm_hwy_to_shp = lightraildev.osm_hwy_to_shp:main'
        ]
    },
    install_requires=[
        # arcpy is a requirement as well, but arcpy is terrible for real
        # python development so buildout can't find it even when installed
        'comtypes>=1.1.2',
        'fiona>=1.6.2',
        'gdal>=1.11.2',
        'overpass>=0.4.0',
        'pypiwin32',
        'pyproj>=1.9.4',
        'shapely>=1.3.0',
        'sqlalchemy>=1.0.9',
        'trimet.model.oracle.trans>=1.4.6',
        'xlsxwriter>=0.8.6'
    ],
    license='GPL',
    long_description=open('README.md').read(),
    packages=find_packages(),
    url='https://github.com/grant-humphries/dev-near-lightrail'
)
