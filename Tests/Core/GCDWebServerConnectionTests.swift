import XCTest

@testable import GCDWebServer_Swift

final class GCDWebServerConnectionTests: XCTestCase {

  func testInit() {
    let server = GCDWebServer()
    server.addHandler(for: "GET", regex: "/test") { _ in
      return nil
    }

    let fakeSocketFileDescriptor: Int32 = 10

    let connection = GCDWebServerConnection(with: server, socket: fakeSocketFileDescriptor)

    XCTAssertNotNil(connection)
    XCTAssert(connection.isRequestNull())
  }
}
