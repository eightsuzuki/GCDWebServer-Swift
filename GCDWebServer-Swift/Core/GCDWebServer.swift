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

#if os(iOS)
  let kDefaultPort: Int = 80
#else
  let kDefaultPort: Int = 8080
#endif

let GCDWebServerOption_Port = "Port"

public typealias GCDWebServerMatchBlock = (
  _ requestMethod: String, _ requestURL: URL, _ requestHeaders: [String: String], _ urlPath: String,
  _ urlQuery: String
) -> GCDWebServerRequest?

public typealias GCDWebServerCompletionBlock = (_ response: GCDWebServerResponse?) -> Void

public typealias GCDWebServerProcessBlock = (_ request: GCDWebServerRequest) -> GCDWebServerResponse?

public typealias GCDWebServerAsyncProcessBlock = (_ request: GCDWebServerRequest, _ completionBlock: GCDWebServerCompletionBlock) -> Void

private func getOption(options: [String: Any]?, key: String, defaultValue: Any) -> Any {
  if let value = options?[key] {
    return value
  }
  return defaultValue
}

public class GCDWebServerHandler {

  public var matchBlock: GCDWebServerMatchBlock
  
  public var asyncProcessBlock: GCDWebServerAsyncProcessBlock

  init(mathcBlock: @escaping GCDWebServerMatchBlock, asyncProcessBlock: @escaping GCDWebServerAsyncProcessBlock) {
    self.matchBlock = mathcBlock
    self.asyncProcessBlock = asyncProcessBlock
  }
}

public class GCDWebServer {

  private var options: [String: Any]?

  public var handlers: [GCDWebServerHandler]

  private let sourceGroup: DispatchGroup

  private var source4: DispatchSourceRead?

  public init() {
    handlers = []
    sourceGroup = DispatchGroup()
  }
  
  public func addHandler(for method: String, regex: String, processBlock: @escaping GCDWebServerProcessBlock) {
    let asyncProcessBlock: GCDWebServerAsyncProcessBlock = { request, completionBlock in
      completionBlock(processBlock(request))
    }
    
    addHandler(for: method, regex: regex, asyncProcessBlock: asyncProcessBlock)
  }
  

  public func addHandler(for method: String, regex: String, asyncProcessBlock: @escaping GCDWebServerAsyncProcessBlock) {
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
      addHandler(with: matchBlock, asyncProcessBlock: asyncProcessBlock)
    }
  }
  
  public func addHandler(with matckBlock: @escaping GCDWebServerMatchBlock, asyncProcessBlock: @escaping GCDWebServerAsyncProcessBlock) {
    let handler = GCDWebServerHandler(mathcBlock: matckBlock, asyncProcessBlock: asyncProcessBlock)
    handlers.insert(handler, at: 0)
  }

  public func removeAllHandlers() {
    handlers.removeAll()
  }

  public func start() -> Bool {
    return start(with: kDefaultPort)
  }

  public func start(with port: Int) -> Bool {
    var options: [String: Any] = [:]
    options[GCDWebServerOption_Port] = kDefaultPort
    return start(with: options)
  }

  public func start(with options: [String: Any]) -> Bool {
    if self.options == nil {
      self.options = options
    }
    return _start()
  }

  private func _start() -> Bool {
    let port = getOption(options: options, key: GCDWebServerOption_Port, defaultValue: 0) as! Int

    var addr4 = sockaddr_in()
    memset(&addr4, 0, MemoryLayout<sockaddr_in>.size)
    addr4.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    addr4.sin_family = sa_family_t(AF_INET)
    addr4.sin_port = in_port_t(port)
    addr4.sin_addr.s_addr = inet_addr("127.0.0.1")

    var bindAddr4 = sockaddr()
    memcpy(&bindAddr4, &addr4, Int(MemoryLayout<sockaddr_in>.size))

    let listeningSocket4 = createListeningSocket(
      useIPv6: false, localAddress: &bindAddr4, length: UInt32(MemoryLayout<sockaddr_in>.size),
      maxPendingConnections: 16)
    if listeningSocket4 <= 0 {
      return false
    }

    source4 = createDispatchSourceWithListeningSocket(
      listeningSocket: listeningSocket4, isIPv6: false)

    source4?.resume()

    return true
  }

  private func createListeningSocket(
    useIPv6: Bool, localAddress: UnsafePointer<sockaddr>, length: socklen_t,
    maxPendingConnections: Int32
  ) -> Int32 {
    let listeningSocket = socket(useIPv6 ? PF_INET6 : PF_INET, SOCK_STREAM, IPPROTO_TCP)
    if listeningSocket > 0 {
      var yes: Int32 = 1
      setsockopt(
        listeningSocket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

      if bind(listeningSocket, localAddress, length) == 0 {
        if listen(listeningSocket, maxPendingConnections) == 0 {
          return listeningSocket
        } else {
          close(listeningSocket)
        }
      } else {
        close(listeningSocket)
      }
    }
    return -1
  }

  private func createDispatchSourceWithListeningSocket(listeningSocket: Int32, isIPv6: Bool)
    -> DispatchSourceRead
  {
    sourceGroup.enter()
    let source = DispatchSource.makeReadSource(fileDescriptor: listeningSocket)

    source.setCancelHandler {
      close(listeningSocket)
      self.sourceGroup.leave()
    }

    source.setEventHandler {
      var remoteSockAddr = sockaddr()
      var remoteAddrLen = socklen_t(MemoryLayout<sockaddr>.size)

      let socket = accept(listeningSocket, &remoteSockAddr, &remoteAddrLen)
      if socket > 0 {
        let connection = GCDWebServerConnection(with: self, socket: socket)
        connection.echo()
      }
    }

    return source
  }

  /// This function must be called after calling start to leave disptach group.
  /// We need to confirm this method will wait for all running processes to finish.
  public func stop() {
    source4?.cancel()
    source4 = nil
    sourceGroup.wait()
  }
}
