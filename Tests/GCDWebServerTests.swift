import XCTest

@testable import GCDWebServer_Swift

final class Tests: XCTestCase {

  func testAddHandler() {
    let server = GCDWebServer()
    XCTAssertNotNil(server)

    server.addHandler(for: "GET", regex: "/test")
    XCTAssertEqual(server.handlersCount(), 1)

    XCTAssertNotNil(
      server.request(
        with: "GET", url: URL(string: "localhost")!, headers: [:], path: "/test", query: [:]))
    XCTAssertNil(
      server.request(
        with: "POST", url: URL(string: "localhost")!, headers: [:], path: "/test", query: [:]))

    server.removeAllHandlers()
    XCTAssertEqual(server.handlersCount(), 0)
    XCTAssertNil(
      server.request(
        with: "GET", url: URL(string: "localhost")!, headers: [:], path: "/test", query: [:]))
  }

  func testStart() {
    let server = GCDWebServer()
    XCTAssert(server.start())

    let clientSocket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)
    var remoteAddr = sockaddr_in()
    remoteAddr.sin_family = sa_family_t(PF_INET)
    remoteAddr.sin_port = 80
    remoteAddr.sin_addr.s_addr = inet_addr("127.0.0.1")

    var bindRemoteAddr4 = sockaddr()
    memcpy(&bindRemoteAddr4, &remoteAddr, Int(MemoryLayout<sockaddr_in>.size))

    let socket = connect(clientSocket, &bindRemoteAddr4, socklen_t(MemoryLayout<sockaddr_in>.size))
    if socket < 0 {
      let errorNumber = errno
      let errorMessage = String(cString: strerror(errorNumber))
      XCTFail("Connect failed with error: \(errorNumber) - \(errorMessage)")
    }

    server.stop()
  }
}
