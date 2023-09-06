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

let kHeadersReadCapacity = 1024

typealias ReadCompletionBlock = (_ success: Bool) -> Void

class GCDWebServerConnection {

  private var server: GCDWebServer

  private var socket: Int32

  private var request: GCDWebServerRequest?

  private var headersData: Data?

  private let CRLFCRLFData: Data = Data(bytes: "\r\n\r\n", count: 4)

  private enum readDataTypes: Int {
    case headers
  }

  public init(with server: GCDWebServer, socket: Int32) {
    self.server = server
    self.socket = socket

    readRequestHeaders()
  }

  private func readRequestHeaders() {
    headersData = Data(capacity: kHeadersReadCapacity)
    readHeaders()

    let method = "GET"
    let url = URL(string: "localhost")!
    let headers: [String: String] = [:]
    let path = "/home"
    let query: [String: String] = [:]

    for handler in server.handlers {
      let request = handler.matchBlock(method, url, headers, path, query)
      if let request {
        self.request = request
        break
      }
    }
  }

  private func readHeaders() {
    readData(dataType: readDataTypes.headers.rawValue, with: Int.max) { success in
      if success {
        let range = self.headersData?.range(
          of: self.CRLFCRLFData, options: [], in: 0..<self.headersData!.count)
        if let range, !range.isEmpty {
        } else {
          self.readHeaders()
        }
      }
    }
  }

  private func readData(dataType: Int, with length: Int, block: @escaping ReadCompletionBlock) {
    let readQueue = DispatchQueue(label: "GCDWebServerConnection.readQueue")
    DispatchIO.read(fromFileDescriptor: socket, maxLength: length, runningHandlerOn: readQueue) {
      buffer, err in
      if err != 0 {
        block(false)
      }
      if buffer.count > 0 {
        buffer.enumerateBytes { chunk, offset, isLast in
          // Inside escaping closure, we cannot modify arguments using inout.
          // Instead, we're modifying intended property based on dataType param.
          switch dataType {
          case readDataTypes.headers.rawValue:
            self.headersData?.append(chunk)
          default:
            return
          }
        }
        block(true)
      } else {
        block(false)
      }
    }
  }

  /// Only used for avoiding unused warning.
  public func echo() {}
}

extension GCDWebServerConnection {

  public func isRequestNull() -> Bool {
    return request == nil
  }
}
