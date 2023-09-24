import XCTest

@testable import GCDWebServer_Swift

final class GCDWebServerDataResponseTests: XCTestCase {

  func testInit() {
    let dataResponse = GCDWebServerDataResponse.response(
      html: "<html><body><p>Hello World</p></body></html>")
    XCTAssertNotNil(dataResponse)
  }
}
