@testable import GCDWebServer_Swift
import XCTest
final class Tests: XCTestCase {
  
  func testAddHandler() {
    let server = GCDWebServer()
    XCTAssertNotNil(server)

    let matchBlock: GCDWebServerMatchBlock = { requestMethod, requestURL, requestHeaders, urlPath, urlQuery in
      return ""
    }
    server.addHandler(with: matchBlock)
    XCTAssertEqual(server.handlersCount(), 1)

    server.removeAllHandlers()
    XCTAssertEqual(server.handlersCount(), 0)
  }
}
