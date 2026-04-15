//
//  HTTPRequestProvider.swift
//  
//
//  Created by Lukáš Valenta on 26.05.2023.
//

import Foundation

/// A protocol that defines a type capable of providing a HTTPRequest for a given API router.
///
/// Implement this protocol to create a custom HTTPRequest provider for your API client.
/// The `AuthorizationType` associated type is used to define the type of authorization used by the API.
public protocol HTTPRequestProvider<AuthorizationType>: Sendable {
    associatedtype AuthorizationType

    /// Returns a HTTPRequest for the given API router.
    ///
    /// - Parameter router: The API router to create a HTTPRequest for.
    /// - Returns: A HTTPRequest configured with the given API router.
    /// - Throws: An error if the HTTPRequest could not be created.
    func getHTTPRequest<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType

    /// Returns a HTTPRequest for the given API router when an unauthorized error occurs.
    ///
    /// - Parameter router: The API router to create a HTTPRequest for.
    /// - Returns: A HTTPRequest configured with the given API router.
    /// - Throws: An error if the HTTPRequest could not be created.
    func getHTTPRequestOnUnAuthorizedError<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType
}

public extension HTTPRequestProvider {
    /// Default implementation of `getHTTPRequestOnUnAuthorizedError(from:)`.
    @inlinable
    func getHTTPRequestOnUnAuthorizedError<RouterType: APIRouter>(from router: RouterType) async throws -> HTTPRequest where RouterType.AuthorizationType == AuthorizationType {
        try await getHTTPRequest(from: router)
    }
}

/// A basic HTTPRequest provider that creates HTTPRequests for a given API router.
public struct BaseHTTPRequestProvider<AuthorizationType, HostnameProvider: RouterBytes.HostnameProvider>: HTTPRequestProvider {
    /// The base URL for the API requests.
    public let hostnameProvider: HostnameProvider

    /// Initializes a new BaseHTTPRequestProvider with the given HostnameProvider.
    ///
    /// - Parameter hostnameProvider: The HostnameProvider for the API requests.
    @inlinable
    public init(hostnameProvider: HostnameProvider) {
        self.hostnameProvider = hostnameProvider
    }

    /// Returns a HTTPRequest for the given API router.
    ///
    /// - Parameter router: The API router to create a HTTPRequest for.
    /// - Returns: A HTTPRequest configured with the given API router.
    /// - Throws: An error if the HTTPRequest could not be created.
    @inlinable
    public func getHTTPRequest<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : APIRouter, AuthorizationType == RouterType.AuthorizationType {
        try router.asHTTPRequest(hostname: hostnameProvider.hostname(for: router))
    }
}

extension BaseHTTPRequestProvider where HostnameProvider == RouterBytes.BaseHostnameProvider {
    /// Initializes a new BaseHTTPRequestProvider with the given hostname as a BaseHostnameProvider.
    ///
    /// - Parameter hostname: The base URL for the API requests.
    @inlinable
    public init(hostname: URL) {
        self.hostnameProvider = HostnameProvider(hostname: hostname)
    }
}

extension BaseHTTPRequestProvider: RouterBytes.HostnameProvider {
    /// Returns the hostname for the given API router.
    ///
    /// - Parameter router: The API router to get the hostname for.
    /// - Returns: The hostname for the given API router.
    @inlinable
    public func hostname(for router: some APIRouter) -> URL {
        hostnameProvider.hostname(for: router)
    }
}

/// A HTTPRequest provider for mocking API requests during testing.
public class MockHTTPRequestProvider<AuthorizationType>: @unchecked Sendable, HTTPRequestProvider {
    /// Indicates if `getHTTPRequest(from:)` has been called.
    public private(set) var getHTTPRequestCalled: Bool = false
    /// Indicates if `getHTTPRequestOnUnAuthorizedError(from:)` has been called.
    public private(set) var getHTTPRequestOnUnAuthorizedErrorCalled = false

    @usableFromInline
    let baseURLProvider: BaseHTTPRequestProvider<AuthorizationType, BaseHostnameProvider>
    
    /// Initializes a new MockHTTPRequestProvider with the given hostname.
    ///
    /// - Parameter hostname: The base URL for the API requests.
    public init(hostname: URL) {
        self.baseURLProvider = .init(hostname: hostname)
    }

    /// Returns a HTTPRequest for the given API router.
    ///
    /// - Parameter router: The API router to create a HTTPRequest for.
    /// - Returns: A HTTPRequest configured with the given API router.
    /// - Throws: An error if the HTTPRequest could not be created.
    public func getHTTPRequest<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : APIRouter, AuthorizationType == RouterType.AuthorizationType {
        getHTTPRequestCalled = true
        return try await baseURLProvider.getHTTPRequest(from: router)
    }
    
    /// Returns a HTTPRequest for the given API router when an unauthorized error occurs.
    ///
    /// - Parameter router: The API router to create a HTTPRequest for.
    /// - Returns: A HTTPRequest configured with the given API router.
    /// - Throws: An error if the HTTPRequest could not be created.
    public func getHTTPRequestOnUnAuthorizedError<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : APIRouter, AuthorizationType == RouterType.AuthorizationType {
        getHTTPRequestOnUnAuthorizedErrorCalled = true
        return try await baseURLProvider.getHTTPRequestOnUnAuthorizedError(from: router)
    }
}

extension MockHTTPRequestProvider: HostnameProvider {
    /// Returns the hostname for the given API router.
    ///
    /// - Parameter router: The API router to get the hostname for.
    /// - Returns: The hostname for the given API router.
    @inlinable
    public func hostname(for router: some APIRouter) -> URL {
        baseURLProvider.hostname(for: router)
    }
}
