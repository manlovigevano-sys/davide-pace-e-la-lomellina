ol.proj.proj4.register(proj4);
//ol.proj.get("EPSG:3857").setExtent([1001681.109061, 5646365.983925, 1004806.668223, 5648065.917215]);
var wms_layers = [];


        var lyr_OpenStreetMap_0 = new ol.layer.Tile({
            'title': 'OpenStreetMap',
            'type':'base',
            'opacity': 1.000000,
            
            
            source: new ol.source.XYZ({
            attributions: ' ',
                url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
            })
        });

        var lyr_ESRISatellite_1 = new ol.layer.Tile({
            'title': 'ESRI Satellite',
            'type':'base',
            'opacity': 0.901000,
            
            
            source: new ol.source.XYZ({
            attributions: ' ',
                url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
            })
        });
var lyr_LombardiaGAI1954_2 = new ol.layer.Tile({
                            source: new ol.source.TileWMS(({
                              url: "https://www.cartografia.servizirl.it/arcgis2/services/BaseMap/Lombardia_GAI_UTM32N/MapServer/WMSServer",
                              attributions: ' ',
                              params: {
                                "LAYERS": "0",
                                "TILED": "true",
                                "VERSION": "1.3.0"},
                            })),
                            title: 'Lombardia GAI - 1954',
                            popuplayertitle: 'Lombardia GAI - 1954',
                            type: 'base',
                            opacity: 0.837000,
                            
                            
                          });
              wms_layers.push([lyr_LombardiaGAI1954_2, 0]);
var format_Museocivicoarcheologico_3 = new ol.format.GeoJSON();
var features_Museocivicoarcheologico_3 = format_Museocivicoarcheologico_3.readFeatures(json_Museocivicoarcheologico_3, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_Museocivicoarcheologico_3 = new ol.source.Vector({
    attributions: ' ',
});
jsonSource_Museocivicoarcheologico_3.addFeatures(features_Museocivicoarcheologico_3);
var lyr_Museocivicoarcheologico_3 = new ol.layer.Vector({
                declutter: false,
                source:jsonSource_Museocivicoarcheologico_3, 
                style: style_Museocivicoarcheologico_3,
                popuplayertitle: 'Museo civico archeologico',
                interactive: true,
                title: '<img src="styles/legend/Museocivicoarcheologico_3.png" /> Museo civico archeologico'
            });
var format_Settoripodericascine_4 = new ol.format.GeoJSON();
var features_Settoripodericascine_4 = format_Settoripodericascine_4.readFeatures(json_Settoripodericascine_4, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_Settoripodericascine_4 = new ol.source.Vector({
    attributions: ' ',
});
jsonSource_Settoripodericascine_4.addFeatures(features_Settoripodericascine_4);
var lyr_Settoripodericascine_4 = new ol.layer.Vector({
                declutter: false,
                source:jsonSource_Settoripodericascine_4, 
                style: style_Settoripodericascine_4,
                popuplayertitle: 'Settori, poderi, cascine',
                interactive: true,
                title: '<img src="styles/legend/Settoripodericascine_4.png" /> Settori, poderi, cascine'
            });
var format_Localitdirinvenimento_5 = new ol.format.GeoJSON();
var features_Localitdirinvenimento_5 = format_Localitdirinvenimento_5.readFeatures(json_Localitdirinvenimento_5, 
            {dataProjection: 'EPSG:4326', featureProjection: 'EPSG:3857'});
var jsonSource_Localitdirinvenimento_5 = new ol.source.Vector({
    attributions: ' ',
});
jsonSource_Localitdirinvenimento_5.addFeatures(features_Localitdirinvenimento_5);
var lyr_Localitdirinvenimento_5 = new ol.layer.Vector({
                declutter: false,
                source:jsonSource_Localitdirinvenimento_5, 
                style: style_Localitdirinvenimento_5,
                popuplayertitle: 'Località di rinvenimento',
                interactive: true,
                title: '<img src="styles/legend/Localitdirinvenimento_5.png" /> Località di rinvenimento'
            });

lyr_OpenStreetMap_0.setVisible(true);lyr_ESRISatellite_1.setVisible(true);lyr_LombardiaGAI1954_2.setVisible(true);lyr_Museocivicoarcheologico_3.setVisible(true);lyr_Settoripodericascine_4.setVisible(true);lyr_Localitdirinvenimento_5.setVisible(true);
var layersList = [lyr_OpenStreetMap_0,lyr_ESRISatellite_1,lyr_LombardiaGAI1954_2,lyr_Museocivicoarcheologico_3,lyr_Settoripodericascine_4,lyr_Localitdirinvenimento_5];
lyr_Museocivicoarcheologico_3.set('fieldAliases', {'fid': 'fid', 'nome': 'nome', 'tipologia': 'tipologia', 'cronologia': 'cronologia', 'precisione': 'precisione', 'fonte': 'fonte', 'note': 'note', 'layer': 'layer', });
lyr_Settoripodericascine_4.set('fieldAliases', {'fid': 'fid', 'nome': 'nome', 'tipologia': 'tipologia', 'cronologia': 'cronologia', 'precisione': 'precisione', 'fonte': 'fonte', 'note': 'note', 'layer': 'layer', });
lyr_Localitdirinvenimento_5.set('fieldAliases', {'fid': 'fid', 'nome': 'nome', 'tipologia': 'tipologia', 'cronologia': 'cronologia', 'precisione': 'precisione', 'fonte': 'fonte', 'note': 'note', 'layer': 'layer', });
lyr_Museocivicoarcheologico_3.set('fieldImages', {'fid': 'TextEdit', 'nome': 'TextEdit', 'tipologia': 'TextEdit', 'cronologia': 'TextEdit', 'precisione': 'TextEdit', 'fonte': 'TextEdit', 'note': 'TextEdit', 'layer': 'TextEdit', });
lyr_Settoripodericascine_4.set('fieldImages', {'fid': 'TextEdit', 'nome': 'TextEdit', 'tipologia': 'TextEdit', 'cronologia': 'TextEdit', 'precisione': 'TextEdit', 'fonte': 'TextEdit', 'note': 'TextEdit', 'layer': 'TextEdit', });
lyr_Localitdirinvenimento_5.set('fieldImages', {'fid': 'TextEdit', 'nome': 'TextEdit', 'tipologia': 'TextEdit', 'cronologia': 'TextEdit', 'precisione': 'TextEdit', 'fonte': 'TextEdit', 'note': 'TextEdit', 'layer': 'TextEdit', });
lyr_Museocivicoarcheologico_3.set('fieldLabels', {'fid': 'no label', 'nome': 'header label - always visible', 'tipologia': 'header label - always visible', 'cronologia': 'inline label - always visible', 'precisione': 'header label - always visible', 'fonte': 'header label - always visible', 'note': 'header label - always visible', 'layer': 'hidden field', });
lyr_Settoripodericascine_4.set('fieldLabels', {'fid': 'no label', 'nome': 'header label - always visible', 'tipologia': 'header label - always visible', 'cronologia': 'inline label - always visible', 'precisione': 'header label - always visible', 'fonte': 'header label - always visible', 'note': 'header label - always visible', 'layer': 'hidden field', });
lyr_Localitdirinvenimento_5.set('fieldLabels', {'fid': 'no label', 'nome': 'header label - always visible', 'tipologia': 'header label - always visible', 'cronologia': 'inline label - always visible', 'precisione': 'header label - always visible', 'fonte': 'header label - always visible', 'note': 'header label - always visible', 'layer': 'hidden field', });
lyr_Localitdirinvenimento_5.on('precompose', function(evt) {
    evt.context.globalCompositeOperation = 'normal';
});