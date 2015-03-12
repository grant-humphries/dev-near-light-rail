// map settings
var map_center = ol.proj.transform(
	[-122.68163, 45.52129], 'EPSG:4326', 'EPSG:3857'
);

// data attributions
var tm_attribution = new ol.Attribution({
	html: 'tiles &copy; <a target="#" href="http://trimet.org/">TriMet</a>; map data'});
var metro_attribution = new ol.Attribution({
	html: 'and &copy; <a target="#" href="http://oregonmetro.gov/rlis">Oregon Metro</a>'});

var attributions = [
	tm_attribution,
	ol.source.OSM.ATTRIBUTION,
	metro_attribution
];

var domain = 'http://maps7.trimet.org'

// map layers
var tm_aerial = new ol.layer.Tile({
	source: new ol.source.XYZ({
		attributions: attributions,
		url: domain + '/tilecache/tilecache.py/1.0.0/hybridOSM/{z}/{x}/{y}'
	})
});

var tm_carto = new ol.layer.Tile({
	source: new ol.source.XYZ({
		attributions: attributions,
		url: domain + '/tilecache/tilecache.py/1.0.0/currentOSM/{z}/{x}/{y}'
	})
});

var dev_taxlots = new ol.layer.Tile({
	source: new ol.source.TileWMS(({
		url: domain + '/gis/geoserver/wms',
		params: {'LAYERS': 'misc-gis:web_map_taxlots', 'TILED': true},
		serverType: 'geoserver'
	}))
});

dev_taxlots.setOpacity(0.5);

var layers = [
	tm_aerial,
	dev_taxlots
];

// map object
var map = new ol.Map({
	layers: layers,
	target: 'map',
	view: new ol.View({
		center: map_center,
		zoom: 15,
		minZoom: 13,
		maxZoom: 19
	})
});

$(document).ready(function(){
	$('.legend-btn').click(function(){
		$('#legend-wrapper').toggle();
	});
});

$(document).ready(function(){
	$('.cntrl-wrapper').hover(function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.6)');
	},
	function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.4)');
	});
});

$(document).ready(function(){
	$('.legend-btn').hover(function(){
		$(this).css('background-color', 'rgba(0, 60, 136, 0.7)');
	},
	function(){
		$(this).css('background-color', 'rgba(0, 60, 136, 0.5)');
	});
});

$(document).ready(function(){
	$('#legend-wrapper').hide();
});

$(document).ready(function(){
	$('#lp-wrapper').hide();
});

$(document).ready(function(){
	$('.legend').hover(function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.75)');
	},
	function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.5)');
	});
});

$(document).ready(function(){
	$('.lyr-cntrl-btn').hover(function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.75)');
	},
	function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.6)');
	});
});

/*//http://openlayers.org/en/master/examples/layer-group.js
function bindInputs(layerid, layer) {
  new ol.dom.Input($(layerid + ' .visible')[0])
      .bindTo('checked', layer, 'visible');
  );
}*/