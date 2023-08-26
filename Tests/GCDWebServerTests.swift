import GCDWebServer_Swift
import XCTest

final class Tests: XCTestCase {

  func testInit() throws {
    let server = GCDWebServer()
    XCTAssertNotNil(server)
  }
}

