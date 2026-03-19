# =============================================================
#  Travel Plan HTML Generator
#  1. Edit TRIP DATA below
#  2. Run script -> index.html written to your working dir
#  3. Distribute: index.html + style.css + app.js  OR
#     push all three to GitHub and enable Pages
#
#  How to find lat/lon:
#    Google Maps: right-click -> copy the numbers shown
#    Or: https://www.latlong.net
# =============================================================

library(httr)
library(jsonlite)

# Set working directory to the folder containing this script
# so style.css and app.js are always found regardless of how R is launched
script_dir <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),  # RStudio
  error = function(e)
    tryCatch(
      dirname(sys.frame(1)$ofile),                     # source()
      error = function(e) getwd()                      # fallback
    )
)
setwd(script_dir)
cat(sprintf("Working directory: %s\n", getwd()))


# ── TRIP DATA  (edit here) ────────────────────────────────────

trip_title <- "Irvine 4-Day Trip"

days <- list(
  
  list(
    label = "Day 1",
    date  = "Thu, Mar 19",
    mode  = "driving",
    stops = list(
      list(name = "Anton Aspire",        lat = 37.408259283039776,  lon = -121.89118465966013, 
           note = "Sweet Home"),
      list(name = "Starbucks @ Paso Robles",             lat = 35.642615235870046,  lon = -120.6867475734939, 
           note = "Coffee Time"),
      list(name = "Shell @ Santa Maria",            lat = 34.95280781644777,    lon = -120.41614525049276, 
           note = "加油"),
      list(name = "Choppa Poke",            lat = 34.43074465827356,   lon = -119.87238073147121, 
           note = "Dinner"),
      list(name = "Currie Hall",            lat = 34.063973596291994,  lon = -118.20088688499247, 
           note = ""),
      list(name = "Marriott Irvine Spectrum",            lat = 33.657648983241565,  lon = -117.74781119777563, 
           note = "Final Destination")
    )
  ),
  
  list(
    label = "Day 2",
    date  = "Fri, Mar 20",
    mode  = "driving",
    stops = list(
      list(name = "Marriott Irvine Spectrum",            lat = 33.657648983241565,  lon = -117.74781119777563, 
           note = "Hotel"),
      list(name = "NEP Cafe",            lat = 33.706328323652045,  lon =  -117.78557838190986,
           note = "Vietnam Brunch"),
      list(name = "OMOMO",            lat = 33.70656848982049,  lon = -117.78760829562826,  
           note = "奶茶"),
      list(name = "Aunara Medical Aesthetic",            lat = 33.661083462718366,  lon = -117.75406658095794,   
           note = "做脸 Est. 1.5h"),
      list(name = "Newport Beach Pier",            lat = 33.60713385231994,  lon = -117.92931947432056,   
           note = ""), 
      list(name = "Fable & Spirit",            lat = 33.6181515683559,  lon = -117.9290680876886,    
           note = "漂亮饭"),
      list(name = "Marriott Irvine Spectrum",            lat = 33.657648983241565,  lon = -117.74781119777563, 
           note = "Hotel")
    )
  ),
  
  list(
    label = "Day 3",
    date  = "Sat, Mar 21",
    mode  = "driving",
    stops = list(
      list(name = "Marriott Irvine Spectrum",            lat = 33.657648983241565,  lon = -117.74781119777563, 
           note = "Hotel"),
      list(name = "The Beachcomber at Crystal Cove",            lat = 33.574285310669346,  lon =  -117.84032031933596, 
           note = "Seafood"),
      list(name = "Mameya Coffee Roasters",            lat = 33.55601540599113,  lon = -117.71036633461324,   
           note = "Coffee"),
      list(name = "Mitsuwa Marketplace 牛舌饭",            lat = 33.68138218581583,  lon = -117.8839843141404,    
           note = ""),
      list(name = "Heybings Desserts",            lat = 33.67959785325547,  lon = -117.90653667832264, 
           note = "甜品店 Optional"), 
      list(name = "Marriott Irvine Spectrum",            lat = 33.657648983241565,  lon = -117.74781119777563, 
           note = "Hotel")
    )
  ), 
  
  list(
    label = "Day 4",
    date  = "Sun, Mar 22",
    mode  = "driving",
    stops = list(
      list(name = "Marriott Irvine Spectrum",            lat = 33.657648983241565,  lon = -117.74781119777563, 
           note = "Hotel"),
      list(name = "BenGong's Tea Irvine",            lat = 33.72806627547318,  lon = -117.78623726896585,  
           note = "本宫的茶"),
      list(name = "Belacan Grill - Malaysian Bistro",            lat = 33.75909813645667,  lon = -117.82630941217026,
           note = "海南鸡饭"),
      list(name = "Makkee Dessert",            lat = 33.993700239644056,  lon = -117.90416829393003, 
           note = "麦记牛奶公司"),
      list(name = "Anton Aspire",        lat = 37.408259283039776,  lon = -121.89118465966013, 
           note = "Sweet Home")
    )
  )
)


# ── VALIDATE ─────────────────────────────────────────────────

cat("=== Validating stops ===\n")
for (i in seq_along(days)) {
  d <- days[[i]]
  cat(sprintf("\n%s -- %s\n", d$label, d$date))
  for (s in d$stops) {
    if (is.null(s$lat) || is.null(s$lon))
      stop(sprintf('Stop "%s" missing lat/lon.', s$name))
    cat(sprintf("  OK  %s\n", s$name))
  }
}
cat("\nAll stops valid.\n")


# ── FETCH OSRM ROUTES ────────────────────────────────────────

fetch_route <- function(stops, mode) {
  profile <- switch(mode, driving="car", cycling="bike", foot="foot", "car")
  coords  <- paste(sapply(stops, function(s) paste0(s$lon, ",", s$lat)), collapse=";")
  url     <- paste0(
    "https://router.project-osrm.org/route/v1/", profile, "/", coords,
    "?overview=full&geometries=geojson&steps=true"
  )
  resp <- GET(url, timeout(30))
  if (http_error(resp)) stop(paste("OSRM HTTP error:", status_code(resp)))
  data <- fromJSON(content(resp, as="text", encoding="UTF-8"), simplifyVector=FALSE)
  if (data$code != "Ok") stop(paste("OSRM error:", data$code))
  route <- data$routes[[1]]
  list(
    geometry = route$geometry,
    distance = round(route$distance / 1609.34, 2),
    duration = round(route$duration / 60),
    legs = lapply(route$legs, function(l) list(
      distance = round(l$distance / 1609.34, 2),
      duration = round(l$duration / 60),
      steps    = lapply(l$steps, function(st) list(geometry = st$geometry))
    ))
  )
}

cat("\n=== Fetching OSRM routes ===\n")
resolved_days <- lapply(seq_along(days), function(i) {
  d <- days[[i]]
  cat(sprintf("  %s (%s)...\n", d$label, d$mode))
  d$route <- tryCatch(
    fetch_route(d$stops, d$mode),
    error = function(e) { cat("    WARNING:", conditionMessage(e), "\n"); NULL }
  )
  d
})
cat("Done.\n")


# ── BUILD JSON ───────────────────────────────────────────────

trip_data <- list(
  title = trip_title,
  days  = lapply(resolved_days, function(d) list(
    label = d$label,
    date  = d$date,
    mode  = d$mode,
    stops = lapply(d$stops, function(s) list(
      name = s$name, lat = s$lat, lon = s$lon,
      note = if (!is.null(s$note)) s$note else ""
    )),
    route = d$route
  ))
)

trip_json_str <- toJSON(trip_data, auto_unbox=TRUE, pretty=FALSE)


# ── ASSEMBLE HTML ────────────────────────────────────────────
# CSS and JS are read from separate files so there are zero
# R string-escaping issues with quotes or special characters.

css_text <- paste(readLines("style.css", warn=FALSE), collapse="\n")
js_text  <- paste(readLines("app.js",    warn=FALSE), collapse="\n")

# Inject trip data into JS via a safe placeholder substitution
js_text <- gsub("__TRIP_JSON__", trip_json_str, js_text, fixed=TRUE)

# Write HTML line by line - no giant paste0, no escape issues
con <- file("index.html", open="wb")
writeLines('<!DOCTYPE html>',                                         con)
writeLines('<html lang="en">',                                        con)
writeLines('<head>',                                                   con)
writeLines('<meta charset="UTF-8"/>',                                  con)
writeLines('<meta name="viewport" content="width=device-width,initial-scale=1.0"/>', con)
writeLines(paste0('<title>', trip_title, '</title>'),                  con)
writeLines('<link rel="preconnect" href="https://fonts.googleapis.com">', con)
writeLines('<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@500;700&family=DM+Sans:wght@300;400;500&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">', con)
writeLines('<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>', con)
writeLines('<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>', con)
writeLines('<style>',                                                  con)
writeLines(css_text,                                                   con)
writeLines('</style>',                                                 con)
writeLines('</head>',                                                  con)
writeLines('<body>',                                                   con)
writeLines('<div id="sidebar">',                                       con)
writeLines('  <div id="header">',                                      con)
writeLines('    <div class="trip-eyebrow">Travel Itinerary</div>',     con)
writeLines('    <div class="trip-title" id="trip-title"></div>',       con)
writeLines('  </div>',                                                 con)
writeLines('  <div id="day-tabs"></div>',                              con)
writeLines('  <div id="stops-panel">',                                 con)
writeLines('    <div class="stops-list" id="stops-list"></div>',       con)
writeLines('  </div>',                                                 con)
writeLines('</div>',                                                   con)
writeLines('<div id="map-wrap"><div id="map"></div></div>',            con)
writeLines('<script>',                                                 con)
writeLines(js_text,                                                    con)
writeLines('</script>',                                                con)
writeLines('</body>',                                                  con)
writeLines('</html>',                                                  con)
close(con)

cat(sprintf("\nWritten: %s\n", normalizePath("index.html")))

if (.Platform$OS.type == "windows") {
  shell.exec("index.html")
} else if (Sys.info()["sysname"] == "Darwin") {
  system("open index.html")
} else {
  system("xdg-open index.html")
}