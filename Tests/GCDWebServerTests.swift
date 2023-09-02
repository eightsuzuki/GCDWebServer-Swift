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

    let clientSocket = socket(AF_INET, SOCK_STREAM, 0)
    var remoteAddr = sockaddr_in()
    remoteAddr.sin_family = sa_family_t(AF_INET)
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

  func testConnection() {
    let serverSocket = socket(AF_INET, SOCK_STREAM, 0)
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = 80
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")

    var bindAddr = sockaddr()
    memcpy(&bindAddr, &addr, Int(MemoryLayout<sockaddr_in>.size))

    if bind(serverSocket, &bindAddr, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0 {
      if listen(serverSocket, 16) == 0 {
        print("OK")
      }
    }

    let clientSocket = socket(AF_INET, SOCK_STREAM, 0)
    var remoteAddr = sockaddr_in()
    remoteAddr.sin_family = sa_family_t(AF_INET)
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
  }
}
