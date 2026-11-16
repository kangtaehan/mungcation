import Flutter
import UIKit
import MapKit
import CryptoKit

private let koreaRegion = MKCoordinateRegion(
  center: CLLocationCoordinate2D(latitude: 35.6, longitude: 128.0),
  span: MKCoordinateSpan(latitudeDelta: 6.2, longitudeDelta: 8.0)
)

private func isInKorea(_ coordinate: CLLocationCoordinate2D) -> Bool {
  (32.5...38.7).contains(coordinate.latitude) &&
    (124.0...132.0).contains(coordinate.longitude)
}

final class MungcationMapPlugin: NSObject, FlutterPlugin {
  private var searches: [UUID: MKLocalSearch] = [:]
  private var directions: [UUID: MKDirections] = [:]
  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = MungcationMapPlugin()
    let channel = FlutterMethodChannel(name: "mungcation/maps", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.register(PetMapFactory(messenger: registrar.messenger()), withId: "mungcation/map")
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "search":
      guard let rawQuery = args["query"] as? String else {
        result(FlutterError(code: "query", message: "검색어를 입력해 주세요.", details: nil)); return
      }
      let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !query.isEmpty, query.count <= 200 else {
        result(FlutterError(code: "query", message: "검색어는 200자 이하로 입력해 주세요.", details: nil)); return
      }
      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = query
      request.resultTypes = [.address, .pointOfInterest]
      request.region = koreaRegion
      if let lat = args["lat"] as? Double, let lon = args["lon"] as? Double {
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        guard CLLocationCoordinate2DIsValid(center) else {
          result(FlutterError(code: "coordinates", message: "현재 위치가 올바르지 않아요.", details: nil)); return
        }
        if isInKorea(center) {
          request.region = MKCoordinateRegion(center: center, latitudinalMeters: 5000, longitudinalMeters: 5000)
        }
      }
      let token = UUID(), search = MKLocalSearch(request: request)
      searches[token] = search
      search.start { [weak self] response, error in
        self?.searches.removeValue(forKey: token)
        guard let response = response else { result(FlutterError(code: "search", message: error?.localizedDescription ?? "장소를 찾지 못했어요.", details: nil)); return }
        result(response.mapItems.filter { isInKorea($0.placemark.coordinate) }.prefix(30).map { item -> [String: Any] in
          let c = item.placemark.coordinate
          let identity = String(format: "%.5f,%.5f", c.latitude, c.longitude)
          let identifier = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
          return ["id": identifier, "name": item.name ?? "이름 없음", "address": item.placemark.title ?? "", "lat": c.latitude, "lon": c.longitude, "phone": item.phoneNumber ?? "", "url": item.url?.absoluteString ?? "", "category": item.pointOfInterestCategory == .park ? "park" : "unknown"]
        })
      }
    case "directions":
      guard let lat = args["lat"] as? Double, let lon = args["lon"] as? Double, let endLat = args["endLat"] as? Double, let endLon = args["endLon"] as? Double, CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon)), CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: endLat, longitude: endLon)) else {
        result(FlutterError(code: "coordinates", message: "출발지와 목적지가 필요해요.", details: nil)); return
      }
      guard isInKorea(CLLocationCoordinate2D(latitude: lat, longitude: lon)), isInKorea(CLLocationCoordinate2D(latitude: endLat, longitude: endLon)) else {
        result(FlutterError(code: "coordinates", message: "국내 산책 경로만 안내할 수 있어요.", details: nil)); return
      }
      let request = MKDirections.Request()
      request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
      request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: endLat, longitude: endLon)))
      request.transportType = .walking
      request.requestsAlternateRoutes = true
      let token = UUID(), service = MKDirections(request: request)
      directions[token] = service
      service.calculate { [weak self] response, error in
        self?.directions.removeValue(forKey: token)
        guard let response = response else { result(FlutterError(code: "directions", message: error?.localizedDescription ?? "이 지역의 도보 경로를 제공하지 못해요.", details: nil)); return }
        result(response.routes.map { route -> [String: Any] in
          var points = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
          route.polyline.getCoordinates(&points, range: NSRange(location: 0, length: points.count))
          return ["name": route.name, "meters": route.distance, "seconds": route.expectedTravelTime, "coordinates": points.map { ["lat": $0.latitude, "lon": $0.longitude] }, "instructions": route.steps.map { $0.instructions }.filter { !$0.isEmpty }]
        })
      }
    case "openPlace":
      guard let lat = args["lat"] as? Double, let lon = args["lon"] as? Double, CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon)) else { result(false); return }
      let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
      item.name = args["name"] as? String
      result(item.openInMaps())
    default: result(FlutterMethodNotImplemented)
    }
  }
}

final class PetMapFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    PetMap(frame: frame, id: viewId, messenger: messenger, arguments: args as? [String: Any] ?? [:])
  }
}
final class PetAnnotation: MKPointAnnotation {
  var kind = "place"
  var identifier = ""
  var points = 0
}
final class PetMap: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let map: MKMapView
  private let channel: FlutterMethodChannel
  private var firstUpdate = true
  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, arguments: [String: Any]) {
    map = MKMapView(frame: frame)
    channel = FlutterMethodChannel(name: "mungcation/map/\(id)", binaryMessenger: messenger)
    super.init()
    map.delegate = self
    map.showsCompass = true
    map.showsScale = true
    map.isRotateEnabled = true
    map.accessibilityLabel = "산책 지도"
    map.setCameraBoundary(MKMapView.CameraBoundary(coordinateRegion: koreaRegion), animated: false)
    map.setCameraZoomRange(MKMapView.CameraZoomRange(minCenterCoordinateDistance: 100, maxCenterCoordinateDistance: 1_500_000), animated: false)
    // Initial viewport only. This is never presented as the user's location.
    map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 36.4, longitude: 127.8), span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)), animated: false)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      if call.method == "update", let args = call.arguments as? [String: Any] { self.update(args); result(nil) }
      else { result(FlutterMethodNotImplemented) }
    }
    update(arguments)
  }
  deinit { channel.setMethodCallHandler(nil); map.delegate = nil }
  func view() -> UIView { map }
  private func coordinates(_ value: Any?) -> [CLLocationCoordinate2D] {
    (value as? [[String: Any]] ?? []).compactMap { point in
      guard let lat = point["lat"] as? Double, let lon = point["lon"] as? Double else { return nil }
      return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
  }
  private func update(_ args: [String: Any]) {
    map.removeOverlays(map.overlays)
    map.removeAnnotations(map.annotations)
    if let segments = args["segments"] as? [[[String: Any]]] {
      for segment in segments { let c = coordinates(segment); if c.count > 1 { let line = MKPolyline(coordinates: c, count: c.count); line.title = "track"; map.addOverlay(line) } }
    }
    let route = coordinates(args["route"])
    if route.count > 1 { let line = MKPolyline(coordinates: route, count: route.count); line.title = "route"; map.addOverlay(line) }
    for place in args["places"] as? [[String: Any]] ?? [] {
      guard let lat = place["lat"] as? Double, let lon = place["lon"] as? Double else { continue }
      let annotation = PetAnnotation(); annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon); annotation.title = place["name"] as? String; annotation.identifier = place["id"] as? String ?? ""; annotation.points = place["points"] as? Int ?? 0; map.addAnnotation(annotation)
    }
    for c in coordinates(args["footprints"]) { let mark = PetAnnotation(); mark.coordinate = c; mark.kind = "paw"; map.addAnnotation(mark) }
    if let current = args["current"] as? [String: Any], let lat = current["lat"] as? Double, let lon = current["lon"] as? Double {
      let mark = PetAnnotation();mark.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon);mark.kind = "current";mark.title = "마지막으로 확인한 위치";map.addAnnotation(mark)
      if firstUpdate || args["center"] as? Bool == true {map.setRegion(MKCoordinateRegion(center: mark.coordinate, latitudinalMeters: 120, longitudinalMeters: 120), animated: !firstUpdate);firstUpdate = false}
    }
    if args["fit"] as? Bool == true {
      let rect = map.overlays.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
      if !rect.isNull {map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 45,left: 35,bottom: 45,right: 35), animated: true)}
      else if !map.annotations.isEmpty {map.showAnnotations(map.annotations, animated: true)}
    }
  }
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
    let renderer = MKPolylineRenderer(polyline: line)
    renderer.strokeColor = line.title == "track" ? UIColor(red: 32/255,green: 92/255,blue: 64/255,alpha: 1) : UIColor.systemBlue
    renderer.lineWidth = 5
    if line.title == "route" { renderer.lineDashPattern = [8,5] }
    return renderer
  }
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let pin = annotation as? PetAnnotation else { return nil }
    if pin.kind == "paw" {
      let view = MKAnnotationView(annotation: pin, reuseIdentifier: nil)
      let label = UILabel(frame: CGRect(x: 0,y: 0,width: 22,height: 22));label.text = "🐾";label.font = .systemFont(ofSize: 16);view.addSubview(label);view.frame = label.frame;view.isEnabled = false;return view
    }
    let view = MKMarkerAnnotationView(annotation: pin, reuseIdentifier: nil)
    view.markerTintColor = pin.kind == "current" ? .systemBlue : UIColor(red: 32/255,green: 92/255,blue: 64/255,alpha: 1)
    view.glyphText = pin.kind == "current" ? "🐾" : (pin.points > 0 ? "+\(pin.points)" : "•")
    view.canShowCallout = pin.kind != "current"
    if pin.kind == "place" {view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)}
    return view
  }
  func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
    guard let pin = view.annotation as? PetAnnotation else {return}
    channel.invokeMethod("selectPlace", arguments: pin.identifier)
  }
}
