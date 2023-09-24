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
let kBodyReadCapacity = 256 * 1024

typealias ReadCompletionBlock = (_ success: Bool) -> Void

typealias ReadHeadersCompletionBlock = (_ extraData: Data?) -> Void

typealias WriteHeadersCompletionBlock = (_ success: Bool) -> Void

typealias WriteDataCompletionBlock = (_ success: Bool) -> Void

typealias ReadBodyCompletionBlock = (_ success: Bool) -> Void

class GCDWebServerConnection {

  private let doubleCRLFData: Data = Data(bytes: "\r\n\r\n", count: 4)

  private let logger = Logger(subsystem: "GCDWebServerConnection.Logger", category: "main")

  private var server: GCDWebServer

  private var handler: GCDWebServerHandler?

  private var socket: Int32

  private var request: GCDWebServerRequest?

  private var headersData: Data?

  private var bodyData: Data?

  private var requestMessage: CFHTTPMessage?

  private var response: GCDWebServerResponse?

  private var responseMessage: CFHTTPMessage?

  private var statusCode: Int?

  private enum readDataTypes: Int {
    case headers
    case body
  }

  public init(with server: GCDWebServer, socket: Int32) {
    self.server = server
    self.socket = socket

    readRequestHeaders()
  }

  // MARK: Read

  private func readData(dataType: Int, with length: Int, block: @escaping ReadCompletionBlock) {
    // TODO: Add tests for all cases.
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
          case readDataTypes.body.rawValue:
            self.bodyData?.append(chunk)
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
    // TODO: Add tests for all cases.
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
            self.handler = handler
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
            // TODO: Add test cases to verify the following line.
            self.startProcessingRequest()
            return
          }

          self.request!.prepareForWriting()
          // TODO: Add usesChunkedTransferEncoding property and use it here.
          if extraData.count > self.request!.contentLength {
            self.abortRequest(with: GCDWebServerClientErrorHTTPStatusCode.badRequest.rawValue)
            return
          }

          // TODO: Support Expect header property and use it here.
          // Note that the above TODO is low prioritized because no common browsers send Expect header.
          // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Expect
          // But since cURL sends, supporting is still valuable.
          self.readBody(with: self.request!.contentLength, initialData: extraData)
        }
      }
    }
  }

  private func readHeaders(with block: @escaping ReadHeadersCompletionBlock) {
    // TODO: Add tests for all cases.
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

  private func readBody(with length: Int, initialData: Data) {
    // TODO: Add tests for all cases.
    if !self.request!.performOpen() {
      self.abortRequest(with: GCDWebServerServerErrorHTTPStatusCode.internalServerError.rawValue)
      return
    }

    if !self.request!.performWriteData(initialData) {
      self.logger.error("Failed writing request body on socket \(self.socket)")
      if !self.request!.performClose() {
        self.logger.error("Failed closing request body for socket \(self.socket)")
      }
      self.abortRequest(with: GCDWebServerServerErrorHTTPStatusCode.internalServerError.rawValue)
      return
    }
    let remainingLength = length - initialData.count

    if remainingLength > 0 {
      self.readBody(with: remainingLength) { success in
        if self.request!.performClose() {
          self.startProcessingRequest()
        } else {
          self.logger.error("Failed closing request body for socket \(self.socket)")
          self.abortRequest(
            with: GCDWebServerServerErrorHTTPStatusCode.internalServerError.rawValue)
        }
      }
    } else {
      if self.request!.performClose() {
        self.startProcessingRequest()
      } else {
        self.logger.error("Failed closing request body for socket \(self.socket)")
        self.abortRequest(with: GCDWebServerServerErrorHTTPStatusCode.internalServerError.rawValue)
      }
    }
  }

  private func readBody(with length: Int, completionBlock: @escaping ReadBodyCompletionBlock) {
    // TODO: Add tests for all cases.
    self.bodyData = Data(capacity: kBodyReadCapacity)
    self.readData(dataType: readDataTypes.body.rawValue, with: length) { success in
      if !success {
        completionBlock(false)
        return
      }

      if self.bodyData!.count > length {
        self.logger.error("Unexpected extra content reading request body on socket \(self.socket)")
        completionBlock(false)
      }

      if !self.request!.performWriteData(self.bodyData!) {
        self.logger.error("Failed writing request body on socket \(self.socket)")
        completionBlock(false)
      }

      let remainingLength = length - self.bodyData!.count
      if remainingLength > 0 {
        self.readBody(with: remainingLength, completionBlock: completionBlock)
      } else {
        completionBlock(true)
      }
    }
  }

  // MARK: Write

  private func writeData(data: Data, with completionBlock: @escaping WriteDataCompletionBlock) {
    // TODO: Add tests for all cases.
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
    // TODO: Add tests for all cases.
    if let responseMessage = self.responseMessage,
      let data = CFHTTPMessageCopySerializedMessage(responseMessage)
    {
      writeData(data: data.takeRetainedValue() as Data) { success in }
    }
  }

  // MARK: Request

  private func abortRequest(with statusCode: Int) {
    // TODO: Add tests for all cases.
    initializeResponseHeaders(with: statusCode)
    writeHeadersWithCompletionBlock { success in }
  }

  private func startProcessingRequest() {
    // TODO: Add tests for all cases.
    let prefilghtResponse = preflightRequest()
    if let prefilghtResponse {
      finishProcessingRequest(response: prefilghtResponse)
    } else {
      if let request = self.request {
        processRequest(request) { response in
          if let response {
            self.finishProcessingRequest(response: response)
          }
        }
      }
    }
  }

  private func preflightRequest() -> GCDWebServerResponse? {
    // TODO: Add tests for all cases.
    // TODO: Add authentication check block.
    let response: GCDWebServerResponse? = nil
    return response
  }

  private func processRequest(
    _ request: GCDWebServerRequest, with completion: @escaping GCDWebServerCompletionBlock
  ) {
    self.handler?.asyncProcessBlock(request, completion)
  }

  private func finishProcessingRequest(response: GCDWebServerResponse) {
    // TODO: Add tests for all cases.
    let response = overrideResponse(response, for: self.request!)
    var hasBody = false

    // Currently, the following line always fails.
    if response.hasBody() {
      // TODO: Replace true with self.virtualHEAD
      // TODO: Implement prepareForReading of GCDWebServerResponse and call it here.
      hasBody = true
    }

    // TODO: Implement performOpen of GCDWebServerResponse and call it here.
    if !hasBody {
      self.response = response
    }

    if self.response != nil {
      // TODO: Add other response properties and logic with them.
      initializeResponseHeaders(with: self.response!.statusCode)
      writeHeadersWithCompletionBlock { success in
        if success {
          if hasBody {
            // TODO: Implement performClose of GCDWebServerResponse and call it here.
          }
        } else if hasBody {
          // TODO: Implement performClose of GCDWebServerResponse and call it here.
        }
      }
    } else {
      abortRequest(with: GCDWebServerServerErrorHTTPStatusCode.internalServerError.rawValue)
    }
  }

  // MARK: Response

  private func initializeResponseHeaders(with statusCode: Int) {
    // TODO: Add header values.
    self.statusCode = statusCode
    let statusDescription: CFString? = nil
    self.responseMessage = CFHTTPMessageCreateResponse(
      kCFAllocatorDefault, statusCode, statusDescription, kCFHTTPVersion1_1
    ).takeRetainedValue()
  }

  private func overrideResponse(_ response: GCDWebServerResponse, for request: GCDWebServerRequest)
    -> GCDWebServerResponse
  {
    // TODO: Add tests for all cases.
    let overrittenResponse = response
    // TODO: Add response properties and logic with them.
    // TODO: Add test cases which cause overriding.
    if response.statusCode >= 200 && response.statusCode < 300 {
      let statusCode =
        request.method == "HEAD" || request.method == "GET"
        ? GCDWebServerRedirectionHTTPStatusCode.notModified.rawValue
        : GCDWebServerClientErrorHTTPStatusCode.preconditionFailed.rawValue
      return GCDWebServerResponse(statusCode: statusCode)
    }
    return overrittenResponse
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
