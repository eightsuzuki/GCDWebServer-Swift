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
import os

let kHeadersReadCapacity = 1024

enum GCDWebServerServerErrorHTTPStatusCode: Int {
  case notImplemented = 501
}

typealias ReadCompletionBlock = (_ success: Bool) -> Void

typealias ReadHeadersCompletionBlock = (_ extraData: Data?) -> Void

typealias WriteHeadersCompletionBlock = (_ success: Bool) -> Void

typealias WriteDataCompletionBlock = (_ success: Bool) -> Void

class GCDWebServerConnection {

  private let doubleCRLFData: Data = Data(bytes: "\r\n\r\n", count: 4)

  private let logger = Logger(subsystem: "GCDWebServerConnection.Logger", category: "main")

  private var server: GCDWebServer

  private var socket: Int32

  private var request: GCDWebServerRequest?

  private var headersData: Data?

  private var requestMessage: CFHTTPMessage?

  private var responseMessage: CFHTTPMessage?

  private var statusCode: Int?

  private enum readDataTypes: Int {
    case headers
  }

  public init(with server: GCDWebServer, socket: Int32) {
    self.server = server
    self.socket = socket

    readRequestHeaders()
  }

  // MARK: Read

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

  private func readRequestHeaders() {
    self.headersData = Data(capacity: kHeadersReadCapacity)
    self.requestMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true).takeRetainedValue()
    readHeaders { extraData in
      if let extraData {
        let requestMethod: CFString? = CFHTTPMessageCopyRequestMethod(self.requestMessage!)?
          .takeRetainedValue()
        let requestHeaders: CFDictionary? = CFHTTPMessageCopyAllHeaderFields(self.requestMessage!)?
          .takeRetainedValue()
        let requestURL: CFURL? = CFHTTPMessageCopyRequestURL(self.requestMessage!)?
          .takeRetainedValue()
        // requestPath and requestQuery should be escaped later.
        let requestPath: String = requestURL != nil ? CFURLCopyPath(requestURL)! as String : "/"
        let charactersToLeaveEscaped: CFString = "" as CFString
        let requestQuery: String? =
          requestURL != nil
          ? CFURLCopyQueryString(requestURL, charactersToLeaveEscaped) as String? : ""

        if let requestMethod, let requestHeaders, let requestURL, let requestQuery {
          let method = requestMethod as String
          let headers = requestHeaders as! [String: String]
          let url = requestURL as URL
          let path = requestPath
          let query = requestQuery

          for handler in self.server.handlers {
            let request = handler.matchBlock(method, url, headers, path, query)
            if let request {
              self.request = request
              break
            }
          }
          if self.request == nil {
            self.abortRequest(with: GCDWebServerServerErrorHTTPStatusCode.notImplemented.rawValue)
            return
          }
          if !self.request!.hasBody() {
            return
          }
          self.logger.info("received")
        }
      }
    }
  }

  private func readHeaders(with block: @escaping ReadHeadersCompletionBlock) {
    readData(dataType: readDataTypes.headers.rawValue, with: Int.max) { success in
      if success {
        let range = self.headersData?.range(
          of: self.doubleCRLFData, options: [], in: 0..<self.headersData!.count)
        if let range, !range.isEmpty {
          let length = range.lowerBound + range.count
          let headersByteData = [UInt8](self.headersData!)

          if !CFHTTPMessageAppendBytes(self.requestMessage!, headersByteData, length) {
            block(nil)
          }
          if !CFHTTPMessageIsHeaderComplete(self.requestMessage!) {
            block(nil)
          }
          block(self.headersData?.subdata(in: length..<self.headersData!.count))
        } else {
          self.readHeaders(with: block)
        }
      }
    }
  }

  // MARK: Request

  private func abortRequest(with statusCode: Int) {
    initializeResponseHeaders(with: statusCode)
    writeHeadersWithCompletionBlock { success in }
  }

  // MARK: Response

  private func initializeResponseHeaders(with statusCode: Int) {
    self.statusCode = statusCode
    let statusDescription: CFString? = nil
    self.responseMessage = CFHTTPMessageCreateResponse(
      kCFAllocatorDefault, statusCode, statusDescription, kCFHTTPVersion1_1
    ).takeRetainedValue()
  }

  // MARK: Write

  private func writeData(data: Data, with completionBlock: @escaping WriteDataCompletionBlock) {
    let dispatchData = data.withUnsafeBytes { DispatchData(bytes: $0) }
    let writeQueue = DispatchQueue(label: "GCDWebServerConnection.writeQueue")
    DispatchIO.write(toFileDescriptor: socket, data: dispatchData, runningHandlerOn: writeQueue) {
      data, error in
      if error == 0 {
        completionBlock(true)
      } else {
        completionBlock(false)
      }
    }
  }

  private func writeHeadersWithCompletionBlock(block: WriteHeadersCompletionBlock) {
    if let responseMessage = self.responseMessage,
      let data = CFHTTPMessageCopySerializedMessage(responseMessage)
    {
      writeData(data: data.takeRetainedValue() as Data) { success in }
    }
  }

  // MARK: Tmp

  /// Only used for avoiding unused warning.
  public func echo() {}
}

extension GCDWebServerConnection {

  public func isRequestNull() -> Bool {
    return self.request == nil
  }
}
