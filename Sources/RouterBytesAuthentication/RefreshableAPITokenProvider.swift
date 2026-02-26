//
//  RefreshableTokenProvider.swift
//  
//
//  Created by Lukáš Valenta on 19.08.2023.
//

import Foundation
import RouterBytes

/// A SettableAPITokenProvider that is based on some settable token storage and refresh provider that handles the refresh
@available(macOS 10.15, *)
public actor RefreshableTokenProvider<
    APIToken: CodableAPITokenType,
    TokenStorage: SettableAPITokenProvider<APIToken>,
    RefreshProvider: RouterBytesAuthentication.RefreshTokenProvider<APIToken>
>: SettableAPITokenProvider {
    /// Initializes a new instance of `TokenManager`.
    ///
    /// - Parameters:
    ///   - apiService: The `APIService` to use for API requests.
    ///   - dateProvider: The `DateProviderType` to use for getting the current date.
    ///   - apiTokenRepository: The `APITokenRepositoryType` to use for storing and retrieving API tokens.
    public init(storage: TokenStorage,
                refreshProvider: RefreshProvider,
                authorizationType: AuthorizationType.Type = AuthorizationType.self,
                apiToken: APIToken.Type = APIToken.self) {
        self.refreshProvider = refreshProvider
        self.storage = storage
    }

    nonisolated
    public var isUserLoggedIn: Bool { storage.isUserLoggedIn }
    
    private var refreshingTask: Task<APIToken, Error>?
    public let storage: TokenStorage
    private let refreshProvider: RefreshProvider


    public var apiToken: APIToken { get async throws {
        try await getAPIToken(forceRefresh: false)
        
    } }

    public func setAPIToken(_ apiToken: APIToken) async throws {
        try await storage.setAPIToken(apiToken)
    }

    public func removeAPITokenFromStorage() async {
        await storage.removeAPITokenFromStorage()
    }

    public func logout() async {
        await removeAPITokenFromStorage()
    }

    public func attemptAPITokenRefresh() async throws {
        _ = try await getAPIToken(forceRefresh: true)
    }
    
    
    /// Retrieves an access token, optionally forcing a refresh.
    ///
    /// - Parameter forceRefresh: Whether or not to force a refresh of the access token.
    ///
    /// - Returns: The access token.
    ///
    /// - Throws: `NotLoggedInError` if the user is not logged in
    /// - Throws: `FailedWithUnAuthorizedError` if the refresh failed.
    private func getAPIToken(forceRefresh: Bool) async throws -> APIToken {
        if let refreshingTask {
            return try await refreshingTask.value
        }

        let refreshingTask = Task { [storage, refreshProvider] in
            let currentToken = try await storage.apiToken

            if try await Self.tokenNeedsRefresh(
                forceRefresh: forceRefresh,
                currentToken: currentToken,
                refreshProvider: refreshProvider
            ) {
                do {
                    let refreshedToken = try await refreshProvider.getRefreshedAPIToken(currentToken: currentToken)
                    try await storage.setAPIToken(refreshedToken)
                    return refreshedToken
                } catch {
                    throw FailedWithUnAuthorizedError(reason: error)
                }
            } else {
                return currentToken
            }
        }

        self.refreshingTask = refreshingTask
        defer { self.refreshingTask = nil }

        return try await refreshingTask.value
    }

    private func refreshIsNeeded(forceRefresh: Bool, currentToken: APIToken) async throws -> Bool {
        if forceRefresh { return true }
        return try await refreshProvider.tokenNeedsToBeRefreshed(currentToken: currentToken)
    }

    static private func tokenNeedsRefresh(forceRefresh: Bool, currentToken: APIToken, refreshProvider: RefreshProvider) async throws -> Bool {
        guard !forceRefresh else { return true }
        return try await refreshProvider.tokenNeedsToBeRefreshed(currentToken: currentToken)
    }
}
