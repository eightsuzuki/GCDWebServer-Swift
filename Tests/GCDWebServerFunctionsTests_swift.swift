import GCDWebServer_Swift

import Foundation
import XCTest

final class GCDWebServerFunctionTest: XCTestCase {
  func testGCDWebServerNormalizeHeaderValue() {
    XCTAssertEqual(GCDWebServerNormalizeHeaderValue("TEXT/PLAIN; Other-header"), "text/plain; Other-header")
    XCTAssertEqual(GCDWebServerNormalizeHeaderValue("PLAIN"), "plain")
  }

}
