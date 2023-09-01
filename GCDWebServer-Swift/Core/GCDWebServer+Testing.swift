import Foundation

/// Extenstion for tests
extension GCDWebServer {

  func handlersCount() -> Int {
    return handlers.count
  }

  func request(with method: String, url: URL, headers: [String: String], path: String, query: [String: String]) -> GCDWebServerRequest? {
    for handler in handlers {
      let request = handler.matchBlock(method, url, headers, path, query)
      if let request {
        return request
      }
    }
    return nil
  }
}
