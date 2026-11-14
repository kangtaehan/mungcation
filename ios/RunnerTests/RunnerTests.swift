import Flutter
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testSearchRejectsAnEmptyQuery() {
    let plugin = MungcationMapPlugin()
    var error: FlutterError?
    plugin.handle(FlutterMethodCall(methodName: "search", arguments: ["query": "  "])) { error = $0 as? FlutterError }
    XCTAssertEqual(error?.code, "query")
  }
  func testSearchRejectsAnOversizedQuery() {
    let plugin = MungcationMapPlugin()
    var error: FlutterError?
    plugin.handle(FlutterMethodCall(methodName: "search", arguments: ["query": String(repeating: "a", count: 201)])) { error = $0 as? FlutterError }
    XCTAssertEqual(error?.code, "query")
  }
  func testSearchRejectsInvalidCenterCoordinates() {
    let plugin = MungcationMapPlugin()
    var error: FlutterError?
    plugin.handle(FlutterMethodCall(methodName: "search", arguments: ["query": "공원", "lat": 91.0, "lon": 127.0])) { error = $0 as? FlutterError }
    XCTAssertEqual(error?.code, "coordinates")
  }
  func testDirectionsRejectMissingCoordinates() {
    let plugin = MungcationMapPlugin()
    var error: FlutterError?
    plugin.handle(FlutterMethodCall(methodName: "directions", arguments: [:])) { error = $0 as? FlutterError }
    XCTAssertEqual(error?.code, "coordinates")
  }
  func testDirectionsRejectCoordinatesOutsideTheGlobe() {
    let plugin = MungcationMapPlugin()
    var error: FlutterError?
    plugin.handle(FlutterMethodCall(methodName: "directions", arguments: ["lat": 91.0, "lon": 127.0, "endLat": 37.0, "endLon": 127.0])) { error = $0 as? FlutterError }
    XCTAssertEqual(error?.code, "coordinates")
  }
  func testFileSharingRejectsAnExternalPath() {
    let plugin = MungcationFilesPlugin()
    var error: FlutterError?
    plugin.handle(FlutterMethodCall(methodName: "share", arguments: ["path": "/etc/passwd"])) { error = $0 as? FlutterError }
    XCTAssertEqual(error?.code, "path")
  }
  func testFileSharingRejectsAMissingPath() {
    let plugin = MungcationFilesPlugin()
    var error: FlutterError?
    plugin.handle(FlutterMethodCall(methodName: "share", arguments: [:])) { error = $0 as? FlutterError }
    XCTAssertEqual(error?.code, "path")
  }

}
