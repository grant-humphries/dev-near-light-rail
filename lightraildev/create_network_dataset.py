# The following links are resources used to create this script
# http://gis.stackexchange.com/questions/109779/
# http://edndoc.esri.com/arcobjects/9.2/NET/06443414-d0a7-455d-a199-dfd49aca7d98.htm
# http://resources.arcgis.com/en/help/arcobjects-net/conceptualhelp/
# index.html#/How_to_create_a_network_dataset/0001000000w7000000/

import shutil
from os.path import basename, dirname, join

from arcpy import env, CheckExtension, CheckInExtension, CheckOutExtension, \
    GetInstallInfo, ListFeatureClasses, SpatialReference
from arcpy.conversion import FeatureClassToFeatureClass
from arcpy.management import CreateFeatureDataset, CreateFileGDB
from comtypes.client import CreateObject, GetModule

ARCOBJECTS_DIR = join(GetInstallInfo()['InstallDir'], 'com')
GetModule(join(ARCOBJECTS_DIR, 'esriDataSourcesFile.olb'))
GetModule(join(ARCOBJECTS_DIR, 'esriGeoDatabase.olb'))
GetModule(join(ARCOBJECTS_DIR, 'esriSystem.olb'))

from comtypes.gen.esriDataSourcesFile import ShapefileWorkspaceFactory
from comtypes.gen.esriDataSourcesGDB import FileGDBWorkspaceFactory
from comtypes.gen.esriGeoDatabase import esriDatasetType, \
    esriNetworkAttributeDataType, esriNetworkAttributeUnits, \
    esriNetworkAttributeUsageType, esriNetworkDatasetType, \
    esriNetworkEdgeConnectivityPolicy, esriNetworkEdgeDirection, \
    esriNetworkElementType, DENetworkDataset, EdgeFeatureSource, \
    EvaluatedNetworkAttribute, IDataElement, IDataset, IDatasetContainer2, \
    IDEGeoDataset, IDENetworkDataset2, IEdgeFeatureSource, IEnumDataset, \
    IEvaluatedNetworkAttribute, IFeatureDatasetExtension, \
    IFeatureDatasetExtensionContainer, IFeatureWorkspace, IGeoDataset, \
    INetworkAttribute2, INetworkBuild, INetworkDataset, \
    INetworkConstantEvaluator, INetworkEvaluator, INetworkFieldEvaluator2, \
    INetworkSource, IWorkspace, IWorkspaceFactory, IWorkspaceExtension2, \
    IWorkspaceExtensionManager, NetworkConstantEvaluator, \
    NetworkFieldEvaluator
from comtypes.gen.esriSystem import IArray, IUID, UID

from lightraildev.common import SHP_DIR

# for some reason esriSystem.Array objects can't be created normally 
# via comtypes, I found a workaround on pg 7 of the linked pdf, below is 
# the object's GUID which can be supplied in place of the object
# http://www.pierssen.com/arcgis10/upload/python/arcmap_and_python.pdf
ARRAY_GUID = "{8F2B6061-AB00-11D2-87F4-0000F8751720}"

OSM_SHP = join(SHP_DIR, 'osm_foot.shp')
GDB_PATH = 'C:/Users/humphrig/Desktop/temp/osm_ped.gdb'
FEAT_DATASET = 'osm_ped_fd'


def create_network_dataset_from_shp():
    """"""

    # create an empty data element for a buildable network dataset
    net = new_obj(DENetworkDataset, IDENetworkDataset2)
    net.Buildable = True
    net.NetworkType = esriNetworkDatasetType(2)

    # open the shapefile and cast to the IGeoDataset interface
    shp_ws_factory = new_obj(ShapefileWorkspaceFactory, IWorkspaceFactory)
    shp_workspace = ctype(shp_ws_factory.OpenFromFile(SHP_DIR, 0),
                          IFeatureWorkspace)
    osm_geodata = ctype(shp_workspace.OpenFeatureClass('fwy'),
                        IGeoDataset)

    # copy the feature dataset's extent and spatial reference to the
    # network dataset data element
    net_geo_elem = ctype(net, IDEGeoDataset)
    net_geo_elem.Extent = osm_geodata.Extent
    net_geo_elem.SpatialReference = osm_geodata.SpatialReference

    # specify the name of the network dataset
    net_element = ctype(net, IDataElement)
    net_element.Name = 'osm_ped_network'

    # create an EdgeFeatureSource object and point it to the osm_ped
    # feature class
    env.workspace = SHP_DIR
    edge_net = new_obj(EdgeFeatureSource, INetworkSource)
    edge_net.Name = 'fwy'
    edge_net.ElementType = esriNetworkElementType(2)

    # set the edge feature source's connectivity settings, connect
    # network through any coincident vertex
    edge_feat = ctype(edge_net, IEdgeFeatureSource)
    edge_feat.ClassConnectivityGroup = 1
    edge_feat.ClassConnectivityPolicy = esriNetworkEdgeConnectivityPolicy(0)
    edge_feat.UsesSubtypes = False

    # add the EdgeFeatureSource object to the data element as a source
    # in the network dataset.
    src_array = new_obj(ARRAY_GUID, IArray)
    src_array.Add(edge_feat)
    net.Sources(edge_feat)

    # # create a new UID that references the NetworkDatasetWorkspaceExtension.
    uid = new_obj(UID, IUID)
    uid.Value = 'esriGeoDatabase.NetworkDatasetWorkspaceExtension'

    # get the workspace extension and create the network dataset based
    # on the data element
    shp_workspace_xm = ctype(shp_workspace, IWorkspaceExtensionManager)
    shp_workspace_ext = ctype(shp_workspace_xm.FindExtension(uid),
                              IWorkspaceExtension2)
    shp_workspace_cont = ctype(shp_workspace_ext, IDatasetContainer2)

    temp_dataset = shp_workspace_cont.CreateDataset(net)

    exit()

    net_dataset = ctype(shp_workspace_cont.CreateDataset(net), INetworkDataset)

    # once the network dataset is created, build it
    net_build = ctype(net_dataset, INetworkBuild)

    print dir(net_build)
    exit()

    net_build.BuildNetwork(net_geo_elem.Extent)


def create_gdb_for_network(drop_gdb=False):
    """"""

    if drop_gdb:
        shutil.rmtree(GDB_PATH)

    gdb_dir = dirname(GDB_PATH)
    gdb_name = basename(GDB_PATH)
    CreateFileGDB(gdb_dir, gdb_name)

    ospn = SpatialReference(2913)
    CreateFeatureDataset(GDB_PATH, FEAT_DATASET, ospn)

    fd_path = join(GDB_PATH, FEAT_DATASET)
    fc_name = basename(OSM_SHP).split('.')[0]
    FeatureClassToFeatureClass(OSM_SHP, fd_path, fc_name)


def create_network_dataset_from_gdb():
    """"""

    # create an empty data element for a buildable network dataset
    net = new_obj(DENetworkDataset, IDENetworkDataset2)
    net.Buildable = True
    net.NetworkType = esriNetworkDatasetType(1)

    # open the feature class and ctype to the IGeoDataset interface
    gdb_ws_factory = new_obj(FileGDBWorkspaceFactory, IWorkspaceFactory)
    gdb_workspace = ctype(gdb_ws_factory.OpenFromFile(GDB_PATH, 0),
                          IFeatureWorkspace)
    gdb_feat_ds = ctype(gdb_workspace.OpenFeatureDataset(FEAT_DATASET),
                        IGeoDataset)

    # copy the feature dataset's extent and spatial reference to the
    # network dataset data element
    net_geo_elem = ctype(net, IDEGeoDataset)
    net_geo_elem.Extent = gdb_feat_ds.Extent
    net_geo_elem.SpatialReference = gdb_feat_ds.SpatialReference

    # specify the name of the network dataset
    net_element = ctype(net, IDataElement)
    net_element.Name = 'osm_ped_network'

    # create an EdgeFeatureSource object and point it to the osm_ped
    # feature class
    env.workspace = GDB_PATH
    osm_foot = ListFeatureClasses('*', 'Polyline', FEAT_DATASET)[0]

    edge_net = new_obj(EdgeFeatureSource, INetworkSource)
    edge_net.Name = osm_foot
    edge_net.ElementType = esriNetworkElementType(2)

    # set the edge feature source's connectivity settings, connect
    # network through any coincident vertex
    edge_feat = ctype(edge_net, IEdgeFeatureSource)
    edge_feat.ClassConnectivityGroup = 1
    edge_feat.ClassConnectivityPolicy = esriNetworkEdgeConnectivityPolicy(0)
    edge_feat.UsesSubtypes = False

    source_array = new_obj(ARRAY_GUID, IArray)
    source_array.Add(edge_net)
    net.Sources = source_array

    add_network_attributes(net, edge_net)

    # get the feature dataset extension and create the network dataset
    # based on the data element.
    osm_data_xc = ctype(gdb_feat_ds, IFeatureDatasetExtensionContainer)
    osm_data_ext = ctype(osm_data_xc.FindExtension(esriDatasetType(19)),
                         IFeatureDatasetExtension)
    osm_data_cont = ctype(osm_data_ext, IDatasetContainer2)
    net_dataset = ctype(osm_data_cont.CreateDataset(net), INetworkDataset)

    # once the network dataset is created, build it
    net_build = ctype(net_dataset, INetworkBuild)
    net_build.BuildNetwork(net_geo_elem.Extent)


def add_network_attributes(net, edge_net):
    """"""

    attribute_array = new_obj(ARRAY_GUID, IArray)
    language = 'VBScript'

    # 1) 'ped_permissions' attribute establishes the streets and trails that
    # pedestrians can and cannot be routed along
    ped_eval_attr = new_obj(EvaluatedNetworkAttribute,
                            IEvaluatedNetworkAttribute)
    ped_attr = ctype(ped_eval_attr, INetworkAttribute2)
    ped_attr.DataType = esriNetworkAttributeDataType(3)  # boolean
    ped_attr.Name = 'ped_permissions'
    ped_attr.Units = esriNetworkAttributeUnits(0)  # unknown
    ped_attr.UsageType = esriNetworkAttributeUsageType(2)  # restriction
    ped_attr.UseByDefault = True

    expression = 'restricted'
    pre_logic = (
        'Set foot_list = CreateObject("System.Collections.ArrayList")'   '\n'
        'foot_list.Add "designated"'                                     '\n'
        'foot_list.Add "permissive"'                                     '\n'
        'foot_list.Add "yes"'                                          '\n\n'

        'Set hwy_list = CreateObject("System.Collections.ArrayList")'    '\n'
        'hwy_list.Add "construction"'                                    '\n'
        'hwy_list.Add "motorway"'                                        '\n'
        'hwy_list.Add "trunk"'                                         '\n\n'

        'If foot_list.Contains([foot]) Then'                             '\n'
        '    restricted = False'                                         '\n'
        'ElseIf _'                                                       '\n'
        '        ([access] = "no") Or _'                                 '\n'
        '        ([foot] = "no") Or _'                                   '\n'
        '        ([indoor] = "yes") Or _'                                '\n'
        '        (hwy_list.Contains([highway])) Then'                    '\n'
        '    restricted = True'                                          '\n'
        'Else'                                                           '\n'
        '    restricted = False'                                         '\n'
        'End If'
    )

    # for esriNetworkEdgeDirection 1 = along, 2 = against
    along_eval = new_obj(NetworkFieldEvaluator, INetworkFieldEvaluator2)
    along_eval.SetLanguage(language)
    along_eval.SetExpression(expression, pre_logic)
    ped_eval_attr.Evaluator.setter(
        ped_eval_attr, edge_net, esriNetworkEdgeDirection(1),
        ctype(along_eval, INetworkEvaluator))

    against_eval = new_obj(NetworkFieldEvaluator, INetworkFieldEvaluator2)
    against_eval.SetLanguage(language)
    against_eval.SetExpression(expression, pre_logic)
    ped_eval_attr.Evaluator.setter(
        ped_eval_attr, edge_net, esriNetworkEdgeDirection(2),
        ctype(against_eval, INetworkEvaluator))

    # for ConstantValue False means traversable (that is, not restricted),
    # for esriNetworkElementType 1 = junction, 2 = edge, 3 = turn
    junc_const = new_obj(NetworkConstantEvaluator, INetworkConstantEvaluator)
    junc_const.ConstantValue = False
    ped_eval_attr.DefaultEvaluator.setter(
        ped_eval_attr, esriNetworkElementType(1),
        ctype(junc_const, INetworkEvaluator))

    edge_const = new_obj(NetworkConstantEvaluator, INetworkConstantEvaluator)
    edge_const.ConstantValue = False
    ped_eval_attr.DefaultEvaluator.setter(
        ped_eval_attr, esriNetworkElementType(2),
        ctype(edge_const, INetworkEvaluator))

    turn_const = new_obj(NetworkConstantEvaluator, INetworkConstantEvaluator)
    turn_const.ConstantValue = False
    ped_eval_attr.DefaultEvaluator.setter(
        ped_eval_attr, esriNetworkElementType(3),
        ctype(turn_const, INetworkEvaluator))

    attribute_array.Add(ped_eval_attr)
    net.Attributes = attribute_array

    # 2) 'length' attribute, in feet
    len_eval_attr = new_obj(EvaluatedNetworkAttribute,
                            IEvaluatedNetworkAttribute)
    len_attr = ctype(len_eval_attr, INetworkAttribute2)
    len_attr.DataType = esriNetworkAttributeDataType(2)  # double
    len_attr.Name = 'length'
    len_attr.Units = esriNetworkAttributeUnits(3)  # feet
    len_attr.UsageType = esriNetworkAttributeUsageType(0)  # cost
    len_attr.UseByDefault = True



    attribute_array.Add(len_eval_attr)

    # 3) 'minutes' attribute, assumes a walking speed of 3 mph
    min_eval_attr = new_obj(EvaluatedNetworkAttribute,
                            IEvaluatedNetworkAttribute)
    min_attr = ctype(min_eval_attr, INetworkAttribute2)
    min_attr.DataType = esriNetworkAttributeDataType(2)  # double
    min_attr.Name = 'minutes'
    min_attr.Units = esriNetworkAttributeUnits(21)  # minutes
    min_attr.UsageType = esriNetworkAttributeUsageType(0)  # cost
    min_attr.UseByDefault = True



    attribute_array.Add(min_eval_attr)

# the following two functions are derived from the linked module and make the
# code more VB.net(ic) the language from which the tutorial this code from is
# written in, all they really do is make comtypes functionality slightly less
# verbose, but that's valuable since they're called so many times
# http://www.pierssen.com/arcgis10/upload/python/snippets102.py


def new_obj(class_, interface):
    """Creates a new comtypes POINTER object where 'class_' is the class
    to be instantiated, 'interface' is the interface to be assigned
    """

    pointer = CreateObject(class_, interface=interface)
    return pointer


def ctype(obj, interface):
    """Casts obj to interface and returns comtypes POINTER"""

    pointer = obj.QueryInterface(interface)
    return pointer


def main():
    """"""

    if CheckExtension('Network') == 'Available':
        CheckOutExtension('Network')
    else:
        print 'Network Analyst extension is checked out by another ' \
              'application or person'
        exit()

    # create_network_dataset_from_shp()
    create_gdb_for_network(True)
    create_network_dataset_from_gdb()
    CheckInExtension('Network')


if __name__ == '__main__':
    main()
