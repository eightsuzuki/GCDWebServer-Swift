import Foundation
import GCDWebServer_Swift
import XCTest

final class GCDWebServerFunctionTests: XCTestCase {
  func testGCDWebServerNormalizeHeaderValue() {
    XCTAssertEqual(
      GCDWebServerNormalizeHeaderValue("TEXT/PLAIN; Other-header"), "text/plain; Other-header")
    XCTAssertEqual(GCDWebServerNormalizeHeaderValue("PLAIN"), "plain")
    XCTAssertNil(GCDWebServerNormalizeHeaderValue(nil))
  }
}
