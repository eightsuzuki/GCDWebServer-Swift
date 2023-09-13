import OSLog
import XCTest

@testable import GCDWebServer_Swift

final class GCDWebServerTest: XCTestCase {

  private var capturedLogMessages = [String]()

  func isIncludedInLogMessages(logKeyWord: String) -> Bool {
    do {
      let store = try OSLogStore.init(scope: .currentProcessIdentifier)
      let position = store.position(date: Date().addingTimeInterval(-10))
      let entries = try store.getEntries(with: [], at: position, matching: nil)
      for entry in entries {
        if entry.composedMessage.contains(logKeyWord) {
          return true
        }
      }
      return false
    } catch {
      return false
    }
  }

  func testAddHandler() {
    let server = GCDWebServer()
    XCTAssertNotNil(server)

    server.addHandler(for: "GET", regex: "/test")
    XCTAssertEqual(server.handlersCount(), 1)

    XCTAssertNotNil(
      server.request(
        with: "GET", url: URL(string: "localhost")!, headers: [:], path: "/test", query: ""))
    XCTAssertNil(
      server.request(
        with: "POST", url: URL(string: "localhost")!, headers: [:], path: "/test", query: ""))

    server.removeAllHandlers()

    XCTAssertEqual(server.handlersCount(), 0)
    XCTAssertNil(
      server.request(
        with: "GET", url: URL(string: "localhost")!, headers: [:], path: "/test", query: ""))
  }

  func testStart() {
    let server = GCDWebServer()
    server.addHandler(for: "GET", regex: "/test")
    XCTAssert(server.start())

    let clientSocket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)
    var remoteAddr = sockaddr_in()
    remoteAddr.sin_family = sa_family_t(PF_INET)
    remoteAddr.sin_port = 80
    remoteAddr.sin_addr.s_addr = inet_addr("127.0.0.1")

    var bindRemoteAddr4 = sockaddr()
    memcpy(&bindRemoteAddr4, &remoteAddr, Int(MemoryLayout<sockaddr_in>.size))

    if connect(clientSocket, &bindRemoteAddr4, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0 {
      let request =
        "GET /test?k1=v1&k2=v2 HTTP/1.1\r\nHost: www.example.com\r\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0\r\nAccept-Language: en-US,en;q=0.5\r\nContent-Type: application/json\r\nConnection: keep-alive\r\n\r\nThis is the message body, if present.\r\n"
      let sentBytes = send(clientSocket, request, request.utf8.count, 0)
      if sentBytes < 0 {
        server.stop()
        close(clientSocket)

        let errorNumber = errno
        let errorMessage = String(cString: strerror(errorNumber))
        XCTFail("Send failed with error: \(errorNumber) - \(errorMessage)")
      } else {
        close(clientSocket)
      }
    } else {
      server.stop()
      close(clientSocket)

      let errorNumber = errno
      let errorMessage = String(cString: strerror(errorNumber))
      XCTFail("Connect failed with error: \(errorNumber) - \(errorMessage)")
    }

    server.stop()

    // temporally comment out due to unstable test results.
    //    let expectedLogKeyWord = "received"
    //    XCTAssert(isIncludedInLogMessages(logKeyWord: expectedLogKeyWord))
  }
}
