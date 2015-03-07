// map settings
var map_center = ol.proj.transform(
	[-122.68163, 45.52129], 'EPSG:4326', 'EPSG:3857'
);

// map layers
var mq_aerial = new ol.layer.Tile({
	source: new ol.source.MapQuest({
		layer: 'sat'
	})
});

var taxlot_layer = new ol.layer.Tile({
	source: new ol.source.TileWMS(({
		url: 'http://maps7.trimet.org/gis/geoserver/wms',
		params: {'LAYERS': 'load:taxlot', 'TILED': true},
		serverType: 'geoserver'
	}))
});

taxlot_layer.setOpacity(0.5);

var layers = [
	mq_aerial,
	taxlot_layer
];

// map object
var map = new ol.Map({
	layers: layers,
	target: 'map',
	view: new ol.View({
		center: map_center,
		zoom: 15
	})
});