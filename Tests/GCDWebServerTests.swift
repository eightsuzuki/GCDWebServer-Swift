@testable import GCDWebServer_Swift
import XCTest
final class Tests: XCTestCase {
  
  func testAddHandler() {
    let server = GCDWebServer()
    XCTAssertNotNil(server)
    
    server.addHandler(for: "GET", regex: "/test")
    XCTAssertEqual(server.handlersCount(), 1)

    server.removeAllHandlers()
    XCTAssertEqual(server.handlersCount(), 0)
  }
}
