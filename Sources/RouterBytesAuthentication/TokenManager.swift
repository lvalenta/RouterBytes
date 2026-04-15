//
//  TokenManager.swift
//  
//
//  Created by Lukáš Valenta on 02.05.2023.
//

import RouterBytes
import Foundation
import CleevioStorage

public struct NotLoggedInError: Error, Hashable { public init() { } }

@available(macOS 10.15.0, *)
public typealias TokenManager = TokenProviderWrappedHTTPRequestProvider

@available(macOS 10.15.0, *)
public struct TokenProviderWrappedHTTPRequestProvider<
    AuthorizationType: APITokenAuthorizationType,
    HostnameProvider: RouterBytes.HostnameProvider,
    APITokenProvider: RouterBytesAuthentication.APITokenProvider
>: HTTPRequestProvider where AuthorizationType.APIToken == APITokenProvider.APIToken {
    public let hostnameProvider: HostnameProvider
    public let tokenProvider: APITokenProvider

    public init(hostnameProvider: HostnameProvider, tokenProvider: APITokenProvider, authorizationType: AuthorizationType.Type = AuthorizationType.self) {
        self.hostnameProvider = hostnameProvider
        self.tokenProvider = tokenProvider
    }

    public func getHTTPRequest<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : RouterBytes.APIRouter, AuthorizationType == RouterType.AuthorizationType {
        let request = try router.asHTTPRequest(hostname: hostnameProvider.hostname(for: router))

        return try await router.authType.authorizedRequest(request: request, with: tokenProvider)
    }

    public func getHTTPRequestOnUnAuthorizedError<RouterType>(from router: RouterType) async throws -> HTTPRequest where RouterType : APIRouter, AuthorizationType == RouterType.AuthorizationType {
        try await tokenProvider.attemptAPITokenRefresh()
        return try await getHTTPRequest(from: router)
    }
}
