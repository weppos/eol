function clustersOnOff(){$("goRadioText").innerHTML="Clusters ON"==$("goRadioText").innerHTML?"Clusters OFF":"Clusters ON",EoLMap.change()}function get_center_lat_long(){var e=new google.maps.LatLngBounds;EoLMap.recs=data.records;for(var a=EoLMap.recs.length,o=0;a>o;o++)e.extend(new google.maps.LatLng(EoLMap.recs[o].h,EoLMap.recs[o].i));return e.getCenter()}var EoLMap={};EoLMap.recs=null,EoLMap.map=null,EoLMap.markerClusterer=null,EoLMap.markers=[],EoLMap.infoWindow=null;var markerSpiderfier=null,statuz=[],statuz_all=[],initial_map=!1;EoLMap.init=function(){center_latlong=get_center_lat_long();var e=new google.maps.LatLng(center_latlong.lat(),center_latlong.lng()),a={zoom:2,center:e,mapTypeId:google.maps.MapTypeId.ROADMAP,scaleControl:!0};EoLMap.map=new google.maps.Map($("map-canvas"),a);{var o=document.createElement("div");new CenterControl(o,EoLMap.map,1)}o.index=1,o.style["padding-top"]="10px",EoLMap.map.controls[google.maps.ControlPosition.TOP_CENTER].push(o),EoLMap.recs=data.records,$("total_markers").innerHTML=data.actual+"<br>Plotted: "+data.count,EoLMap.map.enableKeyDragZoom();var r={keepSpiderfied:!0,event:"mouseover"};markerSpiderfier=new OverlappingMarkerSpiderfier(EoLMap.map,r),EoLMap.infoWindow=new google.maps.InfoWindow,EoLMap.showMarkers(),google.maps.event.addListener(EoLMap.map,"idle",function(){record_history()})},EoLMap.showMarkers=function(){EoLMap.markers=[],EoLMap.markerClusterer&&EoLMap.markerClusterer.clearMarkers();var e=$("markerlist");e.innerHTML="";for(var a=EoLMap.recs.length,o=0;a>o;o++){var r=EoLMap.recs[o].a;""===r&&(r="No catalog number");var n=document.createElement("DIV"),t=document.createElement("A");t.href="#",t.className="title",t.innerHTML=r,n.appendChild(t),e.appendChild(n);var p=new google.maps.LatLng(EoLMap.recs[o].h,EoLMap.recs[o].i),i=new google.maps.Marker({position:p,icon:"https://storage.googleapis.com/support-kms-prod/SNP_2752125_en_v0"}),l=EoLMap.markerClickFunction(EoLMap.recs[o],p);google.maps.event.addListener(i,"click",l),google.maps.event.addDomListener(t,"click",l),EoLMap.markers.push(i),markerSpiderfier.addMarker(i)}markerSpiderfier.addListener("click",function(e){EoLMap.infoWindow.open(EoLMap.map,e)}),markerx=EoLMap.markers,markerSpiderfier.addListener("spiderfy",function(){EoLMap.infoWindow.close()}),window.setTimeout(EoLMap.time,0)},EoLMap.markerClickFunction=function(e,a){return function(o){o.cancelBubble=!0,o.returnValue=!1,o.stopPropagation&&(o.stopPropagation(),o.preventDefault());var r=e.b,n='<div class="info"><h3>'+r+"</h3>";e.l&&(n+='<div class="info-body"><img src="'+e.l+'" class="info-img"/></div><br/>'),e.a&&(n+="Catalog number: "+e.a+"<br/>"),n+='Source portal: <a href="http://www.gbif.org/occurrence/'+e.g+'" target="_blank">GBIF data</a><br/>Publisher: <a href="http://www.gbif.org/publisher/'+e.d+'" target="_blank">'+e.c+'</a><br/>Dataset: <a href="http://www.gbif.org/dataset/'+e.f+'" target="_blank">'+e.e+"</a><br/>",e.j&&(n+="Recorded by: "+e.j+"<br/>"),e.k&&(n+="Identified by: "+e.k+"<br/>"),e.m&&(n+="Event date: "+e.m+"<br/>"),n+="</div>",EoLMap.infoWindow.setContent(n),EoLMap.infoWindow.setPosition(a),EoLMap.infoWindow.open(EoLMap.map)}},EoLMap.clear=function(){for(var e,a=0;e=EoLMap.markers[a];a++)e.setMap(null)},EoLMap.change=function(){EoLMap.clear(),EoLMap.showMarkers()},EoLMap.time=function(){if(document.getElementById("goRadioText"))if("Clusters ON"==$("goRadioText").innerHTML)EoLMap.markerClusterer=new MarkerClusterer(EoLMap.map,EoLMap.markers);else for(var e,a=0;e=EoLMap.markers[a];a++)e.setMap(EoLMap.map);else EoLMap.markerClusterer=new MarkerClusterer(EoLMap.map,EoLMap.markers)};