---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
When we integrated the maps vendor two years ago we deliberately put two layers in front of it, `geo.Geocoder` and `addresses.Service`, so that "we can swap providers whenever we want". Procurement is now actually asking us to quote a switch to a cheaper provider. Before I tell them it's a small job: do those layers buy us what we think they do? Everything that touches geocoding is below.

```go
// internal/geo/geocoder.go
package geo

import (
	"context"

	"github.com/acme-maps/mapsapi"
)

// Geocoder isolates the rest of the app from the maps vendor.
type Geocoder interface {
	Geocode(ctx context.Context, req mapsapi.GeocodeRequest) (*mapsapi.GeocodeResponse, error)
	ReverseGeocode(ctx context.Context, req mapsapi.ReverseRequest) (*mapsapi.GeocodeResponse, error)
}

type vendorGeocoder struct {
	client *mapsapi.Client
}

func New(apiKey string) Geocoder {
	return &vendorGeocoder{client: mapsapi.NewClient(apiKey)}
}

func (g *vendorGeocoder) Geocode(ctx context.Context, req mapsapi.GeocodeRequest) (*mapsapi.GeocodeResponse, error) {
	return g.client.Geocode(ctx, req)
}

func (g *vendorGeocoder) ReverseGeocode(ctx context.Context, req mapsapi.ReverseRequest) (*mapsapi.GeocodeResponse, error) {
	return g.client.ReverseGeocode(ctx, req)
}
```

```go
// internal/addresses/service.go
package addresses

// Service is the application-level entry point for address lookups.
type Service struct {
	geo geo.Geocoder
}

func NewService(g geo.Geocoder) *Service { return &Service{geo: g} }

func (s *Service) Lookup(ctx context.Context, req mapsapi.GeocodeRequest) (*mapsapi.GeocodeResponse, error) {
	return s.geo.Geocode(ctx, req)
}

func (s *Service) LookupPoint(ctx context.Context, req mapsapi.ReverseRequest) (*mapsapi.GeocodeResponse, error) {
	return s.geo.ReverseGeocode(ctx, req)
}
```

```go
// internal/delivery/zones.go
func (h *Handler) assignZone(ctx context.Context, order *Order) error {
	resp, err := h.addresses.Lookup(ctx, mapsapi.GeocodeRequest{
		Address:    order.Street + ", " + order.City,
		Region:     order.CountryCode,
		Components: map[string]string{"postal_code": order.Postcode},
	})
	if err != nil {
		return err
	}
	if resp.Status != "OK" || len(resp.Results) == 0 {
		return ErrUnknownAddress
	}
	best := resp.Results[0]
	if best.Geometry.LocationType == "APPROXIMATE" || best.PartialMatch {
		return ErrAmbiguousAddress
	}
	loc := best.Geometry.Location
	order.Zone = h.zones.Find(loc.Lat, loc.Lng)
	return nil
}
```

```go
// internal/stores/nearest.go
func (f *Finder) StoreNear(ctx context.Context, lat, lng float64) (*Store, error) {
	resp, err := f.addresses.LookupPoint(ctx, mapsapi.ReverseRequest{
		LatLng:     mapsapi.LatLng{Lat: lat, Lng: lng},
		ResultType: []string{"locality"},
	})
	if err != nil {
		return nil, err
	}
	if resp.Status == "ZERO_RESULTS" {
		return nil, ErrNoStore
	}
	for _, c := range resp.Results[0].AddressComponents {
		if contains(c.Types, "locality") {
			return f.byCity[c.LongName], nil
		}
	}
	return nil, ErrNoStore
}
```
