# Offline world map asset

`natural_earth_50m_map_units.json` is derived from Natural Earth's
`ne_50m_admin_0_map_units` dataset, version 5.1.1.

- Source: https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-details/
- Download: https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_map_units.zip
- License: Natural Earth public domain
- Retrieved: 2026-09-07
- SHA-256: `137be126aeeff0d88a43641cb7bdd31ea60c06109cbc8335702750b6a0957b5c`

The WGS84 geometry was projected to a normalized Plate Carrée canvas,
simplified for phone rendering, quantized to `[10000, 5000]`, and serialized as
country/map-unit rings. Map units are intentional: England remains independently
selectable from Scotland, Wales, and Northern Ireland. The runtime never fetches
online map tiles.
