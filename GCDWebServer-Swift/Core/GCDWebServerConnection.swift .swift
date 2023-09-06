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

class GCDWebServerConnection {

  private var server: GCDWebServer

  private var socket: Int32

  private var request: GCDWebServerRequest?

  public init(with server: GCDWebServer, socket: Int32) {
    self.server = server
    self.socket = socket

    readRequestHeaders()
  }

  private func readRequestHeaders() {
    //    readData(length: Int.max)

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

  private func readData(length: Int) {
    let readQueue = DispatchQueue(label: "GCDWebServerConnection.readQueue")
    //    let dispatcher = DispatchIO(type: .stream, fileDescriptor: socket, queue: readQueue) { err in
    //      if err != 0 {
    //        return
    //      }
    //    }
    //    dispatcher.read(offset: 0, length: length, queue: readQueue) { done, buffer, err in
    DispatchIO.read(fromFileDescriptor: socket, maxLength: length, runningHandlerOn: readQueue) {
      buffer, err in
      if err != 0 {
        return
      }
      if buffer.count > 0 {
        print("OK")
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
