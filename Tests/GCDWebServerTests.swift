@testable import GCDWebServer_Swift

import XCTest

final class Tests: XCTestCase {

  func testAddHandler() {
      let server = GCDWebServer()
      XCTAssertNotNil(server)

      server.addHandler()
      XCTAssertEqual(server.handlersCount(), 1)

      server.removeAllHandlers()
      XCTAssertEqual(server.handlersCount(), 0)
    }
  }
