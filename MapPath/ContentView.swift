//
//  ContentView.swift
//  MapPath
//
//  Created by hendra on 25/07/24.
//

import SwiftUI
import MapKit

struct ProfileMarker: View {
    var body: some View {
        Circle()
            .frame(width: 32, height: 32)
            .foregroundStyle(.blue.opacity(0.25))
        Circle()
            .frame(width: 20, height: 20)
            .foregroundStyle(.white)
        Circle()
            .frame(width: 12, height: 12)
            .foregroundStyle(.blue)
    }
}

struct DotMarker: View {
    var body: some View {
        Circle()
            .frame(width: 12, height: 12)
            .foregroundStyle(.red)
    }
}

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct ContentView: View {
    @State private var cameraPosition: MapCameraPosition = .region(.userRegion)
    @State private var results = [MKMapItem]()
    @State private var route: MKRoute?
    @State private var mapSelection: MKMapItem?
    @State private var searchText: String = ""
    @State private var showDetails = false
    @State private var getDirections = false
    @State private var routeDisplaying = false
    @State private var routeDestination: MKMapItem?
    @State private var pathCoordinate: [CLLocationCoordinate2D] = [CLLocationCoordinate2D()]
    
    var body: some View {
        Map(position: $cameraPosition, selection: $mapSelection) {
            Annotation("My Location", coordinate: .location) {
                ZStack {
                    ProfileMarker()
                }
            }
            
            ForEach(pathCoordinate, id: \.self) { item in
                Annotation("", coordinate: item) {
                    ZStack {
                        DotMarker()
                    }
                }
            }
            
            ForEach(results, id: \.self) { item in
                if routeDisplaying {
                    if item == routeDestination {
                        let placemark = item.placemark
                        Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                    }
                } else {
                    let placemark = item.placemark
                    Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                }
            }
            
            if let route {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 6)
            }
        }
        .overlay(alignment: .top) {
            TextField("Search for a location...", text: $searchText)
                .font(.subheadline)
                .padding(12)
                .background(.white)
                .padding()
                .shadow(radius: 10)
        }
        .onSubmit(of: .text) {
            Task { await searchPlaces() }
        }
        .onChange(of: getDirections, { oldValue, newValue in
            if newValue {
                fetchRoute()
            }
        })
        .onChange(of: mapSelection, { oldValue, newValue in
            showDetails = newValue != nil
        })
        .sheet(isPresented: $showDetails) {
            LocationDetailsView(mapSelection: $mapSelection, show: $showDetails, getDirections: $getDirections)
                .presentationDetents([.height(340)])
                .presentationBackgroundInteraction(.enabled(upThrough: .height(340)))
                .presentationCornerRadius(12)
        }
    }
}

extension ContentView {
    func searchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = .userRegion

        let results = try? await MKLocalSearch(request: request).start()
        self.results = results?.mapItems ?? []
    }
    
    func fetchRoute() {
        if let mapSelection {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: .init(coordinate: .location))
            request.destination = mapSelection
            
            Task {
                let result = try? await MKDirections(request: request).calculate()
                route = result?.routes.first
                
                if let route {
                    for step in route.steps {
                        let coordinate = step.polyline.coordinate
                        pathCoordinate.append(coordinate)
                    }
                }
                
                routeDestination = mapSelection
                
                withAnimation(.snappy) {
                    routeDisplaying = true
                    showDetails = false
                    
                    if let rect = route?.polyline.boundingMapRect, routeDisplaying {
                        cameraPosition = .rect(rect)
                    }
                }
            }
        }
    }
}

extension CLLocationCoordinate2D {
    static var location: CLLocationCoordinate2D {
        return .init(latitude: -6.195125, longitude: 106.822832)
    }
}

extension MKCoordinateRegion {
    static var userRegion: MKCoordinateRegion {
        return .init(center: .location, latitudinalMeters: 10000, longitudinalMeters: 10000)
    }
}

#Preview {
    ContentView()
}

