import XCTest

@testable import GCDWebServer_Swift

final class Tests: XCTestCase {

  func testAddHandler() {
    let server = GCDWebServer()
    XCTAssertNotNil(server)

    server.addHandler(for: "GET", regex: "/test")
    XCTAssertEqual(server.handlersCount(), 1)

    XCTAssertNotNil(
      server.request(
        with: "GET", url: URL(string: "localhost")!, headers: [:], path: "/test", query: [:]))
    XCTAssertNil(
      server.request(
        with: "POST", url: URL(string: "localhost")!, headers: [:], path: "/test", query: [:]))

    server.removeAllHandlers()
    XCTAssertEqual(server.handlersCount(), 0)
    XCTAssertNil(
      server.request(
        with: "GET", url: URL(string: "localhost")!, headers: [:], path: "/test", query: [:]))
  }

  func testStart() {
    let server = GCDWebServer()
    XCTAssert(server.start(with: [:]))
  }
}
