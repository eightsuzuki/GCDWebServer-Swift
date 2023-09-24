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

///  This protocol is used by the GCDWebServerConnection to communicate with
///  the GCDWebServerRequest and write the received HTTP body data.
///
///  Note that multiple GCDWebServerBodyWriter objects can be chained together
///  internally e.g. to automatically decode gzip encoded content before
///  passing it on to the GCDWebServerRequest.
///
///  @warning These methods can be called on any GCD thread.
protocol GCDWebServerBodyWriter {
  /// This method is called when the connection is opened.
  ///
  /// Return NO to reject the connection e.g. after validating the local
  /// or remote address.
  func open() -> Bool

  ///  This method is called whenever body data has been received.
  ///
  /// It should return true on success or false on failure and set the "error" argument
  /// which is guaranteed to be non-NULL.
  func write(data: Data) -> Bool

  ///  This method is called after all body data has been received.
  ///
  ///   It should return YES on success or NO on failure and set the "error" argument
  ///   which is guaranteed to be non-NULL.
  func close() -> Bool
}

public class GCDWebServerRequest: GCDWebServerBodyWriter {

  public var method: String

  private var url: URL

  private var headers: [String: String]

  private var path: String

  private var query: String

  public var contentLength: Int

  public var contentType: String?

  private var writer: GCDWebServerBodyWriter?

  private var opened: Bool = false

  public init(
    with method: String, url: URL, headers: [String: String], path: String, query: String
  ) {
    self.method = method
    self.url = url
    self.headers = headers
    self.path = path
    self.query = query

    if let lengthHeader = self.headers["Content-Length"] {
      // TODO: Add usesChunkedTransferEncoding property and use it here.
      self.contentLength = Int(lengthHeader)!
    } else {
      self.contentLength = .max
    }
    self.contentType = GCDWebServerNormalizeHeaderValue(self.headers["Content-Type"])
  }

  // MARK: Status check

  public func hasBody() -> Bool {
    return self.contentType != nil
  }

  // MARK: Write

  public func prepareForWriting() {
    self.writer = self
    // TODO: Add gzip writer pattern here.
  }

  public func performOpen() -> Bool {
    if self.opened {
      return false
    }
    self.opened = true
    // TODO: Add error handling when self.writer is null.
    return self.writer!.open()
  }

  public func performWriteData(_ data: Data) -> Bool {
    // TODO: Add error handling when self.writer is null.
    return self.writer!.write(data: data)
  }

  public func performClose() -> Bool {
    // TODO: Add error handling when self.writer is null.
    return self.writer!.close()
  }

  // MARK: GCDWebServerBodyWriter

  public func open() -> Bool {
    return true
  }

  public func write(data: Data) -> Bool {
    return true
  }

  public func close() -> Bool {
    return true
  }
}
