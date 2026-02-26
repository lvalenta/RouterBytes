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
        // If a refresh is already in progress, await it — this is the key deduplication mechanism
        if let refreshingTask {
            return try await refreshingTask.value
        }
        
        // CRITICAL: For forced refresh (after 401/invalidAccessToken), create and store the
        // refresh task BEFORE any suspension point. This prevents actor reentrancy from allowing
        // concurrent callers to each create their own refresh task. Without this, multiple
        // concurrent 401 responses would each trigger a separate refresh request — and because
        // the server invalidates old tokens on the first successful refresh, all subsequent
        // refresh attempts would fail with an invalid refresh token, causing forced sign-out.
        if forceRefresh {
            let refreshingTask = Task { [storage, refreshProvider] in
                let currentToken = try await storage.apiToken
                return try await refreshProvider.getRefreshedAPIToken(currentToken: currentToken)
            }
            
            self.refreshingTask = refreshingTask
            
            do {
                let token = try await refreshingTask.value
                try await setAPIToken(token)
                self.refreshingTask = nil
                return token
            } catch {
                self.refreshingTask = nil
                throw FailedWithUnAuthorizedError(reason: error)
            }
        }
        
        // Proactive refresh path: check if the current token is about to expire
        let apiToken = try await storage.apiToken
        
        guard try await refreshProvider.tokenNeedsToBeRefreshed(currentToken: apiToken) else {
            return apiToken
        }
        
        // Re-check after suspension points: another caller may have started a refresh while
        // we were reading the token and checking expiry. Between this check and setting
        // self.refreshingTask below, there are no suspension points (Task creation is
        // synchronous), so no other caller can interleave.
        if let refreshingTask {
            return try await refreshingTask.value
        }
        
        let refreshingTask = Task { [refreshProvider] in
            return try await refreshProvider.getRefreshedAPIToken(currentToken: apiToken)
        }
        
        self.refreshingTask = refreshingTask
        
        do {
            let token = try await refreshingTask.value
            try await setAPIToken(token)
            self.refreshingTask = nil
            return token
        } catch {
            self.refreshingTask = nil
            throw FailedWithUnAuthorizedError(reason: error)
        }
    }

    private func refreshIsNeeded(forceRefresh: Bool, currentToken: APIToken) async throws -> Bool {
        if forceRefresh { return true }
        return try await refreshProvider.tokenNeedsToBeRefreshed(currentToken: currentToken)
    }
}
