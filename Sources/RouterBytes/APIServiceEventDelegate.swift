//
//  APIServiceDelegate.swift
//  
//
//  Created by Lukáš Valenta on 30.04.2023.
//

import Foundation

/// A protocol for handling events in an API service.
/// An object implementing this protocol can receive callbacks from an `APIService` instance when certain events occur during a network request.
///
/// Example usage:
/// ```
/// struct MyAPIServiceDelegate: APIServiceEventDelegate {
///     var logoutAction: (() async -> Void)?
///
///     func requestFired(request: HTTPRequest, body: Data?) {
///         log.info(request.cURL(body: body, pretty: true))
///     }
///
///     func responseReceived(from request: HTTPRequest, body: Data?, data: Data, response: HTTPResponse) {
///         log.debug("Request: \(request)\nResponse: \(data.asString(pretty: true) ?? "could not parse")")
///     }
///
///     func responseDecoded<T>(_ value: T) {
///         log.debug(value)
///     }
///
///     func requestFailedWithUnAuthorizedError(router: some APIRouter) async {
///         log.error("Request failed with unAuthorizedError: \(router)")
///         await logoutAction?()
///     }
/// }
/// ```
public protocol APIServiceEventDelegate: Sendable {
    /// Notifies the delegate that a network request has been fired.
    ///
    /// - Parameter request: The HTTP request instance that was fired.
    /// - Parameter body: Optional HTTP body associated with the request.
    func requestFired(request: HTTPRequest, body: Data?)

    /// Notifies the delegate that a network response has been received.
    ///
    /// - Parameters:
    ///   - request: The HTTP request instance that was fired.
    ///   - body: Optional HTTP body associated with the request.
    ///   - data: The data returned in the response.
    ///   - response: The `HTTPResponse` object for the response.
    func responseReceived(from request: HTTPRequest, body: Data?, data: Data, response: HTTPResponse)

    /// Notifies the delegate that a response has been decoded.
    ///
    /// - Parameter value: The decoded value of type `T`.
    func responseDecoded<T: Sendable>(_ value: T)

    /// Notifies the delegate that a request failed with an unauthorized error.
    ///
    /// - Parameter router: The APIRouter instance that failed with an unauthorized error.
    func requestFailedWithUnAuthorizedError(router: some APIRouter) async
}

public extension APIServiceEventDelegate {
    /// Default implementation of `requestFired(request:)`.
    @inlinable
    func requestFired(request: HTTPRequest, body: Data?) { }

    /// Default implementation of `responseReceived(data:response:)`.
    @inlinable
    func responseReceived(from request: HTTPRequest, body: Data?, data: Data, response: HTTPResponse) { }

    /// Default implementation of `responseDecoded(_:)`.
    @inlinable
    func responseDecoded<T: Sendable>(_ value: T) { }

    /// Default implementation of `requestFailedWithUnAuthorizedError(router:)`.
    @inlinable
    func requestFailedWithUnAuthorizedError(router: some APIRouter) async { }
}
