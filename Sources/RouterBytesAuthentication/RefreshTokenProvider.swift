//
//  RefreshTokenProvider.swift
//  
//
//  Created by Lukáš Valenta on 13.08.2023.
//

import Foundation
import RouterBytes

/// A protocol that defines functions that handle the refreshing logic for RefreshableTokenProvider
public protocol RefreshTokenProvider<APIToken>: Sendable {
    /// The type of API token to be refreshed.
    associatedtype APIToken: RefreshableAPITokenType

    /// Asynchronously gets a refreshed access token.
    /// - Returns: A refreshed access token.
    func getRefreshedAPIToken(currentToken: APIToken) async throws -> APIToken

    func tokenNeedsToBeRefreshed(currentToken: APIToken) async throws -> Bool
}

/// A simple implementation of RefreshTokenProvider that uses its provided APIService and through provided RefreshTokenAPIRouter returns refreshed APIToken
@available(macOS 10.15, *)
public struct APIRouterRefreshTokenProvider<
    APIToken: RefreshableAPITokenType,
    RefreshTokenAPIRouter: RouterBytesAuthentication.RefreshTokenAPIRouter,
    APIService: APIServiceType & Sendable,
    HostnameProvider: RouterBytes.HostnameProvider,
    DateProvider: DateProviderType
>: RefreshTokenProvider where RefreshTokenAPIRouter.APIToken == APIToken {

    private let apiService: APIService
    private let dateProvider: DateProvider
    let hostnameProvider: HostnameProvider

    public init(apiService: APIService,
                hostnameProvider: HostnameProvider,
                dateProvider: DateProvider = RouterBytesAuthentication.DateProvider(),
                apiToken: APIToken.Type = APIToken.self,
                refreshTokenAPIRouter: RefreshTokenAPIRouter.Type = RefreshTokenAPIRouter.self) {
        self.apiService = apiService
        self.dateProvider = dateProvider
        self.hostnameProvider = hostnameProvider
    }

    public func getRefreshedAPIToken(currentToken: APIToken) async throws -> APIToken {
        let router = RefreshTokenAPIRouter(previousToken: currentToken)

        let urlRequest = try router.asURLRequest(hostname: hostnameProvider.hostname(for: router)).withBearerToken(currentToken.refreshToken.description)

        let (data, urlResponse) = try await apiService.getDataFromNetwork(for: urlRequest)

        let response = try router.getToken(data: data, response: urlResponse, apiService: apiService)
        return response
    }

    public func tokenNeedsToBeRefreshed(currentToken: APIToken) async throws -> Bool {
        currentToken.needsToBeRefreshed(currentDate: dateProvider.currentDate())
    }
}
