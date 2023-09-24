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

/// This protocol is used by the GCDWebServerConnection to communicate with
/// the GCDWebServerResponse and read the HTTP body data to send.
///
/// Note that multiple GCDWebServerBodyReader objects can be chained together
/// internally e.g. to automatically apply gzip encoding to the content before
/// passing it on to the GCDWebServerResponse.
///
/// @warning These methods can be called on any GCD thread.
protocol GCDWebServerBodyReader {

  /// This method is called before any body data is sent.
  ///
  /// It should return YES on success or NO on failure and set the "error" argument
  /// which is guaranteed to be non-NULL.
  func open() -> Bool
}

public class GCDWebServerResponse: GCDWebServerBodyReader {

  public var statusCode: Int

  public var contentType: String?

  public var contentLength: Int

  private var reader: GCDWebServerBodyReader?

  private var opened: Bool = false

  public init() {
    self.statusCode = GCDWebServerSuccessfulHTTPStatusCode.ok.rawValue
    self.contentLength = .max
  }

  public convenience init(statusCode: Int) {
    self.init()
    self.statusCode = statusCode
  }

  public func hasBody() -> Bool {
    return self.contentType != nil
  }

  public func prepareForReading() {
    self.reader = self
    // TODO: Add gzip writer pattern here.
  }

  public func performOpen() -> Bool {
    if self.opened || self.reader == nil {
      return false
    }
    self.opened = true
    return self.reader!.open()
  }

  // MARK: Class methods

  class func response(with statusCode: Int) -> GCDWebServerResponse {
    return GCDWebServerResponse(statusCode: statusCode)
  }

  // MARK: GCDWebServerBodyReader

  func open() -> Bool {
    return true
  }
}
