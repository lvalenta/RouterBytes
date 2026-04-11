//
//  URLRequestProvider.swift
//  
//
//  Created by Lukáš Valenta on 26.05.2023.
//

import Foundation

/// A protocol that defines a type capable of providing a URLRequest for a given API router.
///
/// Implement this protocol to create a custom URLRequest provider for your API client.
/// The `AuthorizationType` associated type is used to define the type of authorization used by the API.
public protocol URLRequestProvider<AuthorizationType>: Sendable {
    associatedtype AuthorizationType

    /// Returns a URLRequest for the given API router.
    ///
    /// - Parameter router: The API router to create a URLRequest for.
    /// - Returns: A URLRequest configured with the given API router.
    /// - Throws: An error if the URLRequest could not be created.
    func getURLRequest<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType

    /// Returns a URLRequest for the given API router when an unauthorized error occurs.
    ///
    /// - Parameter router: The API router to create a URLRequest for.
    /// - Returns: A URLRequest configured with the given API router.
    /// - Throws: An error if the URLRequest could not be created.
    func getURLRequestOnUnAuthorizedError<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType
}

public extension URLRequestProvider {
    /// Default implementation of `getURLRequestOnUnAuthorizedError(from:)`.
    @inlinable
    func getURLRequestOnUnAuthorizedError<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType {
        try await getURLRequest(from: router)
    }
}

/// A basic URLRequest provider that creates URLRequests for a given API router.
public struct BaseURLRequestProvider<AuthorizationType, HostnameProvider: RouterBytes.HostnameProvider>: URLRequestProvider {
    /// The base URL for the API requests.
    public let hostnameProvider: HostnameProvider

    /// Initializes a new BaseURLRequestProvider with the given HostnameProvider.
    ///
    /// - Parameter hostnameProvider: The HostnameProvider for the API requests.
    @inlinable
    public init(hostnameProvider: HostnameProvider) {
        self.hostnameProvider = hostnameProvider
    }

    /// Returns a URLRequest for the given API router.
    ///
    /// - Parameter router: The API router to create a URLRequest for.
    /// - Returns: A URLRequest configured with the given API router.
    /// - Throws: An error if the URLRequest could not be created.
    @inlinable
    public func getURLRequest<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : APIRouter, AuthorizationType == RouterType.AuthorizationType {
        try router.asHTTPRequest(hostname: hostnameProvider.hostname(for: router))
    }
}

extension BaseURLRequestProvider where HostnameProvider == RouterBytes.BaseHostnameProvider {
    /// Initializes a new BaseURLRequestProvider with the given hostname as a BaseHostnameProvider.
    ///
    /// - Parameter hostname: The base URL for the API requests.
    @inlinable
    public init(hostname: URL) {
        self.hostnameProvider = HostnameProvider(hostname: hostname)
    }
}

extension BaseURLRequestProvider: RouterBytes.HostnameProvider {
    /// Returns the hostname for the given API router.
    ///
    /// - Parameter router: The API router to get the hostname for.
    /// - Returns: The hostname for the given API router.
    @inlinable
    public func hostname(for router: some APIRouter) -> URL {
        hostnameProvider.hostname(for: router)
    }
}

/// A URLRequest provider for mocking API requests during testing.
public class MockURLRequestProvider<AuthorizationType>: @unchecked Sendable, URLRequestProvider {
    /// Indicates if `getURLRequest(from:)` has been called.
    public private(set) var getURLRequestCalled: Bool = false
    /// Indicates if `getURLRequestOnUnAuthorizedError(from:)` has been called.
    public private(set) var getURLRequestOnUnAuthorizedErrorCalled = false

    @usableFromInline
    let baseURLProvider: BaseURLRequestProvider<AuthorizationType, BaseHostnameProvider>
    
    /// Initializes a new MockURLRequestProvider with the given hostname.
    ///
    /// - Parameter hostname: The base URL for the API requests.
    public init(hostname: URL) {
        self.baseURLProvider = .init(hostname: hostname)
    }

    /// Returns a URLRequest for the given API router.
    ///
    /// - Parameter router: The API router to create a URLRequest for.
    /// - Returns: A URLRequest configured with the given API router.
    /// - Throws: An error if the URLRequest could not be created.
    public func getURLRequest<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : APIRouter, AuthorizationType == RouterType.AuthorizationType {
        getURLRequestCalled = true
        return try await baseURLProvider.getURLRequest(from: router)
    }
    
    /// Returns a URLRequest for the given API router when an unauthorized error occurs.
    ///
    /// - Parameter router: The API router to create a URLRequest for.
    /// - Returns: A URLRequest configured with the given API router.
    /// - Throws: An error if the URLRequest could not be created.
    public func getURLRequestOnUnAuthorizedError<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : APIRouter, AuthorizationType == RouterType.AuthorizationType {
        getURLRequestOnUnAuthorizedErrorCalled = true
        return try await baseURLProvider.getURLRequestOnUnAuthorizedError(from: router)
    }
}

extension MockURLRequestProvider: HostnameProvider {
    /// Returns the hostname for the given API router.
    ///
    /// - Parameter router: The API router to get the hostname for.
    /// - Returns: The hostname for the given API router.
    @inlinable
    public func hostname(for router: some APIRouter) -> URL {
        baseURLProvider.hostname(for: router)
    }
}
