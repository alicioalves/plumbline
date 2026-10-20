---
type: llm
focus: last_message
weight: 1
---
PASS if the answer identifies that both `geo.Geocoder` and `addresses.Service` take and return the vendor's own types (`mapsapi.GeocodeRequest`, `mapsapi.ReverseRequest`, `*mapsapi.GeocodeResponse`) and simply forward each call, so the callers (`assignZone`, `StoreNear`) still work entirely in the vendor's vocabulary (status strings `"OK"` / `"ZERO_RESULTS"`, `Results[0]`, `Geometry.LocationType == "APPROXIMATE"`, `PartialMatch`, `AddressComponents` with `Types` / `LongName`), AND frames it as an abstraction problem: the two layers add indirection but neither offers a different, application-level way of thinking about geocoding (false or shallow abstraction, leaky abstraction, layers at the same level as the vendor client, or equivalent), so switching providers would still mean rewriting every caller, AND recommends a fix at the right level: one layer that owns translation into the app's own types and operations (e.g. `Locate(ctx, address) (Coordinates, error)` with app-defined not-found / ambiguous results, `CityAt(ctx, point)`), with vendor types confined to its implementation, and the redundant second layer removed or given a genuinely distinct role.

FAIL if the vendor types flowing through both layers are not raised, if the answer says the layers already make a provider switch easy, or if the only fix is to merge or rename the two wrappers (or add an interface for mocking) while they keep passing vendor request/response types.
