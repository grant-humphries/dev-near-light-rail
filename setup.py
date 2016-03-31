from setuptools import find_packages, setup

setup(
    name='lightraildev',
    version='0.2.0',
    author='Grant Humphries',
    dependency_links=['http://dev.trimet.org/pypi/dist/'],
    description='',
    entry_points={
        'console_scripts': []
    },
    install_requires=[
        # arcpy is a requirement as well, but arcpy is terrible for
        # real python development so buildout can't find it
        # 'arcpy',
        'fiona>=1.6.2',
        'shapely>=1.3',
        'sqlalchemy>=1.0.9',
        'trimet.model.oracle.trans>=1.4.6'
    ],
    license='GPL',
    long_description=open('README.md').read(),
    packages=find_packages(),
    url='https://github.com/grant-humphries/dev-near-lightrail'
)
