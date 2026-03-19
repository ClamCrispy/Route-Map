const TRIP = __TRIP_JSON__;
const PAL = [
  {start:"#2a9460",mid:"#2a6bc8",end:"#c8692a",line:"#2a6bc8"},
  {start:"#7b3fa0",mid:"#c05a2a",end:"#2a7a5a",line:"#7b3fa0"},
  {start:"#1a6b9a",mid:"#8a3060",end:"#5a8a20",line:"#1a6b9a"}
];

let rl=[], ml=[], segLayers=[];

const map = L.map("map").setView([34.05,-118.27],11);
L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",{
  attribution:"OpenStreetMap | CARTO", maxZoom:19
}).addTo(map);

document.getElementById("trip-title").textContent = TRIP.title;

// Build day tabs
const tabsEl = document.getElementById("day-tabs");
TRIP.days.forEach(function(d,i){
  var btn = document.createElement("button");
  btn.className = "day-tab" + (i===0 ? " active" : "");
  btn.innerHTML =
    "<span class=\"day-tab-label\">" + d.label + "</span>" +
    "<span class=\"day-tab-date\">"  + d.date  + "</span>";
  btn.onclick = function(){
    document.querySelectorAll(".day-tab").forEach(function(t,j){
      t.classList.toggle("active", j===i);
    });
    renderDay(i);
  };
  tabsEl.appendChild(btn);
});

function highlightSeg(si, segs){
  segs.forEach(function(s,i){
    s.vis.setStyle({weight: i===si ? 5 : 3, opacity: i===si ? 1 : 0.3});
    s.glow.setStyle({opacity: i===si ? 0.25 : 0.04});
  });
}

function resetSegs(segs, c){
  segs.forEach(function(s){
    s.vis.setStyle({color:c.line, weight:4, opacity:0.85});
    s.glow.setStyle({opacity:0.13});
  });
}

function makePopup(from, to, leg){
  var factor = 0.92;  // adjust this: 0.80 = 20% faster, 0.90 = 10% faster
  var adjusted = Math.round(leg.duration * factor);
  var h = Math.floor(adjusted / 60);
  var m = adjusted % 60;
  var timeStr = h > 0 ? h + "h" + (m < 10 ? "0" : "") + m + "min" : m + "min";
  return "<b>" + from + " \u2192 " + to + "</b><br>" +
    leg.distance + " mi&nbsp;&nbsp;~" + timeStr;
}

function renderDay(idx){
  var day = TRIP.days[idx];
  var c   = PAL[idx % PAL.length];

  rl.forEach(function(l){ map.removeLayer(l); });
  ml.forEach(function(l){ map.removeLayer(l); });
  rl=[]; ml=[]; segLayers=[];

  document.getElementById("stops-list").innerHTML = "";

  // Build stop list
  day.stops.forEach(function(s,i){
    var isStart = i===0;
    var isEnd   = i===day.stops.length-1 && day.stops.length>1;
    var color   = isStart ? c.start : (isEnd ? c.end : c.mid);
    var label   = String.fromCharCode(65+i);

    var row = document.createElement("div");
    row.className = "stop-row";
    row.style.animationDelay = (i*0.07) + "s";

    row.innerHTML =
      "<div class=\"stop-badge\"" +
        " style=\"background:" + color + "18;color:" + color + ";border-color:" + color + "\"" +
        " onclick=\"map.flyTo([" + s.lat + "," + s.lon + "],15,{duration:1.2})\"" +
        " title=\"Zoom to on map\">" + label + "</div>" +
      "<div class=\"stop-info\">" +
        "<div class=\"stop-name\">" + s.name + "</div>" +
      "</div>";

    // Connector appended directly to row so position:absolute is relative to .stop-row
    if(i < day.stops.length-1){
      var conn = document.createElement("div");
      conn.className = "seg-connector";
      conn.dataset.seg = i;
      conn.title = "Click to highlight route";
      row.appendChild(conn);
    }

    document.getElementById("stops-list").appendChild(row);

    // Map marker
    var iconHtml =
      "<div style=\"width:30px;height:30px;border-radius:50%;" +
      "background:" + color + ";color:#fff;" +
      "display:flex;align-items:center;justify-content:center;" +
      "font-family:DM Mono,monospace;font-weight:500;font-size:12px;" +
      "box-shadow:0 2px 8px " + color + "55;border:2px solid white\">" + label + "</div>";

    var icon = L.divIcon({className:"", html:iconHtml, iconSize:[30,30], iconAnchor:[15,15]});

    var popHtml = "<b>" + s.name + "</b>" +
      (s.note ? "<br><span style=\"font-size:12px;color:#555\">" + s.note + "</span>" : "");

    ml.push(L.marker([s.lat, s.lon], {icon:icon}).bindPopup(popHtml).addTo(map));
  });

  // Draw routes
  if(day.route && day.route.legs && day.route.legs.length > 0){

    // Fit map to full route
    var fitLine = L.geoJSON(day.route.geometry, {style:{opacity:0}}).addTo(map);
    map.fitBounds(fitLine.getBounds(), {padding:[50,50]});
    map.removeLayer(fitLine);

    // Split geometry per leg using step coordinate counts
    var allCoords = day.route.geometry.coordinates;
    var cursor = 0;

    day.route.legs.forEach(function(leg, i){
      var from = day.stops[i].name;
      var to   = day.stops[i+1].name;
      var legCoords;

      if(leg.steps && leg.steps.length > 0){
        var cnt = 0;
        leg.steps.forEach(function(st){
          cnt += st.geometry.coordinates.length - 1;
        });
        cnt++;
        legCoords = allCoords.slice(cursor, cursor + cnt);
        cursor += cnt - 1;
      } else {
        legCoords = allCoords;
      }

      var lls = legCoords.map(function(co){ return [co[1], co[0]]; });

      var glow = L.polyline(lls, {color:c.line, weight:10, opacity:0.13, lineCap:"round"}).addTo(map);
      var vis  = L.polyline(lls, {color:c.line, weight:4,  opacity:0.85, lineCap:"round"}).addTo(map);
      var hit  = L.polyline(lls, {color:"transparent", weight:24, opacity:0.001}).addTo(map);

      var popTxt = makePopup(from, to, leg);
      hit.bindPopup(popTxt);

      hit.on("click", function(e){
        highlightSeg(i, segLayers);
        document.querySelectorAll(".seg-connector").forEach(function(el){
          el.classList.remove("active");
        });
        var conn = document.querySelector(".seg-connector[data-seg=\"" + i + "\"]");
        if(conn) conn.classList.add("active");
        this.openPopup(e.latlng);
      });

      segLayers.push({glow:glow, vis:vis, hit:hit});
      rl.push(glow, vis, hit);
    });

    map.on("popupclose", function(){
      resetSegs(segLayers, c);
      document.querySelectorAll(".seg-connector").forEach(function(el){
        el.classList.remove("active");
      });
    });

    // Wire sidebar connectors
    document.querySelectorAll(".seg-connector").forEach(function(el){
      el.addEventListener("click", function(){
        var si  = parseInt(this.dataset.seg);
        var leg = day.route.legs[si];
        highlightSeg(si, segLayers);
        document.querySelectorAll(".seg-connector").forEach(function(e){
          e.classList.remove("active");
        });
        this.classList.add("active");
        var lls2 = segLayers[si].vis.getLatLngs();
        var mid  = lls2[Math.floor(lls2.length/2)];
        segLayers[si].hit.openPopup(mid);
        map.panTo(mid, {animate:true, duration:0.6});
      });
    });

  } else if(day.route){
    var glow = L.geoJSON(day.route.geometry,{style:{color:c.line,weight:10,opacity:0.13,lineCap:"round"}}).addTo(map);
    var vis  = L.geoJSON(day.route.geometry,{style:{color:c.line,weight:4, opacity:0.85,lineCap:"round"}}).addTo(map);
    rl.push(glow, vis);
    map.fitBounds(vis.getBounds(), {padding:[50,50]});
  }
}

renderDay(0);