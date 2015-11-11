// Define map settings
var map_center = ol.proj.transform(
	[-122.68163, 45.52129], 'EPSG:4326', 'EPSG:3857'
);


// Establish data attribution
var tm_attribution = new ol.Attribution({
	html: 'tiles &copy; <a target="#" href="http://trimet.org/">TriMet</a>; map data'});
var metro_attribution = new ol.Attribution({
	html: 'and &copy; <a target="#" href="http://oregonmetro.gov/rlis">Oregon Metro</a>'});

var attributions = [
	tm_attribution,
	ol.source.OSM.ATTRIBUTION,
	metro_attribution
];


// Initialize map layers
var domain = 'http://maps7.trimet.org'

base_maps = new ol.layer.Group({
	'title': 'Base Maps',
	layers: [
		new ol.layer.Tile({
			title: 'TriMet-OSM Streets',
			type: 'base',
			visible: false,
			source: new ol.source.XYZ({
				attributions: attributions,
				url: domain + '/tilecache/tilecache.py/1.0.0/currentOSM/{z}/{x}/{y}'
			})
		}),
		new ol.layer.Tile({
			title: 'TriMet Hybrid',
			type: 'base',
			visible: true,
			source: new ol.source.XYZ({
				attributions: attributions,
				url: domain + '/tilecache/tilecache.py/1.0.0/hybridOSM/{z}/{x}/{y}'
			})
		})
	]
});

overlays = new ol.layer.Group({
	'title': 'Overlays',
	layers: [
		new ol.layer.Tile({
			title: 'Tax Lots',
			opacity: 0.5,
			source: new ol.source.TileWMS({
				url: domain + '/gis/geoserver/wms',
				params: {'LAYERS': 'misc-gis:web_map_taxlots', 'TILED': true},
				serverType: 'geoserver'
			})
		})
	]
});

var layers = [
	base_maps,
	overlays
];


// Initial map object, view, and controls
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

var layerSwitcher = new ol.control.LayerSwitcher({
	tipLabel: 'layer control' // Optional label for button
});
map.addControl(layerSwitcher)



map.on('singleclick', function(evt) {
  document.getElementById('info').innerHTML = '';
  var viewResolution = /** @type {number} */ (view.getResolution());
  var url = wmsSource.getGetFeatureInfoUrl(
      evt.coordinate, viewResolution, 'EPSG:3857',
      {'INFO_FORMAT': 'text/html'});
  if (url) {
    document.getElementById('info').innerHTML =
        '<iframe seamless src="' + url + '"></iframe>';
  }
});


map.on('pointermove', function(evt) {
  if (evt.dragging) {
    return;
  }
  var pixel = map.getEventPixel(evt.originalEvent);
  var hit = map.forEachLayerAtPixel(pixel, function(layer) {
    return true;
  });
  map.getTargetElement().style.cursor = hit ? 'pointer' : '';
});




// Legend functionality
$(document).ready(function(){
	$('#legend-wrapper').hide();

	$('.legend-btn').click(function(){
		$('#legend-wrapper').show();
		$('#legend-btn-wrapper').hide();
	});

	$('.legend').click(function(){
		$('#legend-wrapper').hide();
		$('#legend-btn-wrapper').show();
	});
});


// Legend appearance
$(document).ready(function(){
	$('.cntrl-wrapper').hover(function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.6)');
	},
	function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.4)');
	});

	$('.legend-btn').hover(function(){
		$(this).css('background-color', 'rgba(0, 60, 136, 0.7)');
	},
	function(){
		$(this).css('background-color', 'rgba(0, 60, 136, 0.5)');
	});

	$('.legend').hover(function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.8)');
	},
	function(){
		$(this).css('background-color', 'rgba(255, 255, 255, 0.6)');
	});
});