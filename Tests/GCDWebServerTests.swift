@testable import GCDWebServer_Swift

import XCTest

final class GCDWebServerConnectionTests: XCTestCase {

  func testInit() {
    let server = GCDWebServer()
    server.addHandler(for: "GET", regex: "/test")
    let connection = GCDWebServerConnection(with: server)

    XCTAssertNotNil(connection)
    XCTAssert(connection.isRequestNull())
  }
}
