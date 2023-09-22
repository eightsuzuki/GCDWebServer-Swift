import XCTest

@testable import GCDWebServer_Swift

final class GCDWebServerResponseTests: XCTestCase {

  func testInit() {
    let response = GCDWebServerResponse.response(
      with: GCDWebServerSuccessfulHTTPStatusCode.ok.rawValue)
    XCTAssertNotNil(response)
  }
}
