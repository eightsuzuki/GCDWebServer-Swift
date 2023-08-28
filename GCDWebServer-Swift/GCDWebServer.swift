/*
 Copyright (c) 2012-2019, Pierre-Olivier Latour
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public typealias GCDWebServerMatchBlock = (
  _ requestMethod: String, _ requestURL: URL, _ requestHeaders: [String: String], _ urlPath: String,
  _ urlQuery: [String: String]
) -> GCDWebServerRequest?

class GCDWebServerHandler {

  fileprivate var matchBlock: GCDWebServerMatchBlock

  init(mathcBlock: @escaping GCDWebServerMatchBlock) {
    self.matchBlock = mathcBlock
  }
}
public class GCDWebServer {

  fileprivate var handlers: [GCDWebServerHandler]

  public init() {
    handlers = []
  }

  public func addHandler(with matckBlock: @escaping GCDWebServerMatchBlock) {
    let handler = GCDWebServerHandler(mathcBlock: matckBlock)
    handlers.insert(handler, at: 0)
  }

  public func addHandler(for method: String, regex: String) {
    let expression: NSRegularExpression?
    do {
      expression = try NSRegularExpression(pattern: regex, options: .caseInsensitive)
    } catch {
      expression = nil
    }

    if let expression {
      let matchBlock: GCDWebServerMatchBlock = {
        requestMethod, requestURL, requestHeaders, urlPath, urlQuery in
        if requestMethod != method {
          return nil
        }

        let matches = expression.matches(in: urlPath, range: NSMakeRange(0, urlPath.count))
        if matches.count == 0 {
          return nil
        }
        return GCDWebServerRequest(
          with: requestMethod, url: requestURL, headers: requestHeaders, path: urlPath,
          query: urlQuery)
      }
      addHandler(with: matchBlock)
    }
  }

  public func removeAllHandlers() {
    handlers.removeAll()
  }
}
/// Extenstion for tests
extension GCDWebServer {

  func handlersCount() -> Int {
    return handlers.count
  }

  func request(
    with method: String, url: URL, headers: [String: String], path: String, query: [String: String]
  ) -> GCDWebServerRequest? {
    for handler in handlers {
      let request = handler.matchBlock(method, url, headers, path, query)
      if let request {
        return request
      }
    }
    return nil
  }
}
