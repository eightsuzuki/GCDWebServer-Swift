import OSLog
import XCTest

@testable import GCDWebServer_Swift

final class GCDWebServerTests: XCTestCase {

  private enum SpecialCharacters {
    static let CRLF = "\r\n"
  }

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

    let processBlock: GCDWebServerProcessBlock = { _ in
      return GCDWebServerDataResponse(html: "<html><body><p>Hello World</p></body></html>")
    }

    server.addHandler(for: "GET", regex: "/test", processBlock: processBlock)
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
    // TODO: Check if returned response is the same with the expected one.
    let server = GCDWebServer()

    server.addHandler(for: "GET", regex: "/test") { _ in
      return GCDWebServerDataResponse(html: "<html><body><p>Hello World</p></body></html>")
    }

    XCTAssert(server.start())

    let clientSocket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)
    var remoteAddr = sockaddr_in()
    remoteAddr.sin_family = sa_family_t(PF_INET)
    remoteAddr.sin_port = 80
    remoteAddr.sin_addr.s_addr = inet_addr("127.0.0.1")

    var bindRemoteAddr4 = sockaddr()
    memcpy(&bindRemoteAddr4, &remoteAddr, Int(MemoryLayout<sockaddr_in>.size))

    guard connect(clientSocket, &bindRemoteAddr4, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
    else {
      server.stop()
      close(clientSocket)

      let errorNumber = errno
      let errorMessage = String(cString: strerror(errorNumber))
      XCTFail("Connect failed with error: \(errorNumber) - \(errorMessage)")
      return
    }

    let method = "GET"
    let path = "/test?k1=v1&k2=v2"
    let host = "www.example.com"
    let requestBody = "This is the message body, if present."
    // Need to add \r\n count to calculate Content-Length.
    let contentLength = requestBody.utf8.count + SpecialCharacters.CRLF.utf8.count
    let contentType = "text/plain"
    let request =
      "\(method) \(path) HTTP/1.1\(SpecialCharacters.CRLF)Host: \(host)\(SpecialCharacters.CRLF)User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0\(SpecialCharacters.CRLF)Accept-Language: en-US,en;q=0.5\r\nContent-Length: \(contentLength)\(SpecialCharacters.CRLF)Content-Type: \(contentType)\(SpecialCharacters.CRLF)Connection: keep-alive\(SpecialCharacters.CRLF)\(SpecialCharacters.CRLF)\(requestBody)\(SpecialCharacters.CRLF)"

    guard send(clientSocket, request, request.utf8.count, 0) > 0 else {
      server.stop()
      close(clientSocket)

      let errorNumber = errno
      let errorMessage = String(cString: strerror(errorNumber))
      XCTFail("Send failed with error: \(errorNumber) - \(errorMessage)")
      return
    }

    var responseBuffer = [UInt8](repeating: 0, count: 1024)
    recv(clientSocket, &responseBuffer, responseBuffer.count, 0)
    close(clientSocket)

    let response = String(cString: responseBuffer)
    let expectedResponse = "HTTP/1.1 200 OK\(SpecialCharacters.CRLF)\(SpecialCharacters.CRLF)"
    let isResponseMatched = expectation(
      description: "Check if a returned response is matched with the expected one.")
    if response == expectedResponse {
      isResponseMatched.fulfill()
    }
    server.stop()
    wait(for: [isResponseMatched], timeout: 1)
  }
}
