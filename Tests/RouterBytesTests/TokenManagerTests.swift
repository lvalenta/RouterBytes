//
//  TokenManagerTests.swift
//  
//
//  Created by Lukáš Valenta on 02.05.2023.
//

import XCTest
import RouterBytesAuthentication
import RouterBytes

nonisolated(unsafe) fileprivate var dateProvider = DateProviderMock(date: Date())

@available(iOS 15.0, *)
open class TokenManagerTestCase<AuthorizationType: APITokenAuthorizationType, Router: RefreshTokenAPIRouter>: XCTestCase where AuthorizationType.APIToken: Codable & RefreshableAPITokenType, AuthorizationType.APIToken: Equatable, AuthorizationType.APIToken.AccessToken: Equatable, AuthorizationType.APIToken.RefreshToken: Equatable, Router.AuthorizationType == AuthorizationType {
    var sut: TokenManager<
        AuthorizationType,
        MockHTTPRequestProvider<AuthorizationType>,
        RefreshableTokenProvider<
            AuthorizationType.APIToken,
            APITokenRepositoryMock<AuthorizationType.APIToken>,
            APIRouterRefreshTokenProvider<
                AuthorizationType.APIToken,
                Router,
                    APIRouterService<AuthorizationType, NetworkingServiceMock, MockHTTPRequestProvider<AuthorizationType>>,
                MockHTTPRequestProvider<AuthorizationType>,
                DateProviderMock
            >
        >
    >!
    var tokenRepository: APITokenRepositoryMock<AuthorizationType.APIToken>!
    var hostnameProvider: HostnameProvider { httpRequestProvider }
    var httpRequestProvider: MockHTTPRequestProvider<AuthorizationType>!
    public var onRefreshNetworkCall: ((HTTPRequest, Data?) -> (Data, HTTPResponse))!
    
    override open func setUp() {
        dateProvider = .init(date: Date())
        let networkingService = NetworkingServiceMock(onDataCall: { request, body, _ in
            self.onRefreshNetworkCall(request, body)
        })
        
        tokenRepository = APITokenRepositoryMock(apiToken: nil)
        
        onRefreshNetworkCall = { _, _ in
            XCTFail("Refresh token action should not be called")
            fatalError()
        }
        
        self.httpRequestProvider = MockHTTPRequestProvider(hostname: URL(string: "https://cleevio.com")!)
        
        sut = TokenManager(
            hostnameProvider: httpRequestProvider,
            tokenProvider: .init(storage: tokenRepository, refreshProvider: .init(
                apiService: APIRouterService(networkingService: networkingService, httpRequestProvider: httpRequestProvider),
                hostnameProvider: httpRequestProvider,
                dateProvider: dateProvider
            )),
            authorizationType: AuthorizationType.self
        )
    }
    
    func setLoggedIn(expiration: Date = Date.distantFuture) {
        fatalError("Logged in has to be set")
    }

    func refreshingHelper(signedInTokenExpiration: Date,
                          forceRefresh: Bool,
                          executeBeforeCheck: (() async throws -> Void)? = nil,
                          file: StaticString = #filePath,
                          line: UInt = #line) async throws {
        setLoggedIn(expiration: signedInTokenExpiration)
        
        let accessToken: String = "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiI4ZmZiYWJjOS1mMTc5LTQyMmEtYWQ1My0yYWQ3YmQzOTk0YTEiLCJleHAiOjE2NzU3ODI3MjAsImlzcyI6ImNvbS5kcm9ucHJvLm1haW5hcGkiLCJ0eXBlIjoiQUNDRVNTIn0.7OjvRrOZgc8EuCjtOzdUPBZTKhhxm3m5p5oTxryjfPbUdjDAGq5X8HoyN2YFA_UQNRxSb6LLsujTxDEnsnvifQ"

        let refreshToken = "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiI4ZmZiYWJjOS1mMTc5LTQyMmEtYWQ1My0yYWQ3YmQzOTk0YTEiLCJleHAiOjE2NzU3ODU0MjAsImlzcyI6ImNvbS5kcm9ucHJvLm1haW5hcGkiLCJ0eXBlIjoiUkVGUkVTSCJ9.u87LWGKaCecebc8qS2m37KJG8kT0bVBjBIo1RuuRGMkIpg3Dss4Y_VgNz-k5r2iB1JoDtLUwh1huR9m0vptzHw"

        let expiration: Int = 900
        
        let refreshResponse = """
        {
            "refreshParameter" : "\(refreshToken)",
            "expiresInSParameter" : \(expiration),
            "accessParameter" : "\(accessToken)"
        }
        """.data(using: .utf8)!

        let apiTokenInData = """
        {
            "refresh" : "\(refreshToken)",
            "expiresInS" : \(expiration),
            "access" : "\(accessToken)"
        }
        """.data(using: .utf8)!

        let tokenResponse = try! JSONDecoder().decode(AuthorizationType.APIToken.self, from: apiTokenInData)

        let expectation = XCTestExpectation(description: "TokenManager should try to refresh token")

        let refreshRouter = RefreshTokenRouter()
        let expectedRefreshHTTPRequest = try refreshRouter
            .asHTTPRequest(hostname: hostnameProvider.hostname(for: refreshRouter))
            .withBearerToken(try tokenRepository.apiToken.refreshToken.description)
        let expectedRefreshBody = try refreshRouter.encodedBody()
        
        onRefreshNetworkCall = { request, body in
            XCTAssertEqual(expectedRefreshHTTPRequest, request)
            XCTAssertEqual(expectedRefreshBody, body)
            expectation.fulfill()
            return (refreshResponse, HTTPResponse(status: 200))
        }
        
        try await executeBeforeCheck?()

        do {
            if forceRefresh {
                try await sut.tokenProvider.attemptAPITokenRefresh()
            }
            let token = try await sut.tokenProvider.apiToken

            XCTAssertEqual(token.accessToken, tokenResponse.accessToken, file: file, line: line)
            XCTAssertEqual(token.refreshToken, tokenResponse.refreshToken, file: file, line: line)
            XCTAssertEqual(try tokenRepository.apiToken, tokenResponse, file: file, line: line)
        } catch {
            print(error)
            XCTFail(file: file, line: line)
        }

        await fulfillment(of: [expectation])
    }
}
    
@available(iOS 15.0, *)
final class TokenManagerTests: TokenManagerTestCase<BearerAuthorizationType, RefreshTokenRouter> {
    override func setLoggedIn(expiration: Date = Date.distantFuture) {
        tokenRepository.apiTokenStream.store(.init(
            accessToken: UUID().uuidString,
            refreshToken: UUID().uuidString,
            expiration: expiration
        ))
    }

    func testRefreshTokenNotLoggedIn() async {
        do {
            _ = try await sut.tokenProvider.apiToken.refreshToken
            XCTFail("GetRefreshToken should throw an error")
        } catch is NotLoggedInError {
        } catch {
            XCTFail("Incorrect error type, expected: NotLoggedInError, got: \(error.self)")
        }
    }

    func testAccessTokenNotLoggedIn() async {
        do {
            _ = try await sut.tokenProvider.apiToken.accessToken
            XCTFail("GetRefreshToken should throw an error")
        } catch is NotLoggedInError {
        } catch {
            XCTFail("Incorrect error type, expected: NotLoggedInError, got: \(error.self)")
        }
    }

    func testRefreshTokenLoggedIn() async throws {
        setLoggedIn()
        let accessToken = try await sut.tokenProvider.apiToken.accessToken

        XCTAssertEqual(accessToken, try tokenRepository.apiToken.accessToken)
    }

    func testAccessTokenLoggedIn() async throws {
        setLoggedIn()
        let accessToken = try await sut.tokenProvider.apiToken.refreshToken

        XCTAssertEqual(accessToken, try tokenRepository.apiToken.refreshToken)
    }

    func testApiTokenIsUpdatedAfterRefresh() async throws {
        try await refreshingHelper(signedInTokenExpiration: Date.distantFuture, forceRefresh: true)
    }

    func testAccessTokenIsRefreshedWhenExpired() async throws {
        try await refreshingHelper(signedInTokenExpiration: Date.distantPast, forceRefresh: false)
    }

    func testAccessTokenIsRefreshedWithMinuteToExpiration() async throws {
        try await refreshingHelper(signedInTokenExpiration: Date(timeIntervalSinceNow: 60), forceRefresh: false)
    }
}

@available(iOS 15.0, *)
final class TokenManagerHTTPRequestProviderTests: TokenManagerTestCase<RouterBytes.BearerAuthorizationType, RefreshTokenRouter> {
    override func setLoggedIn(expiration: Date = Date.distantFuture) {
        tokenRepository.apiTokenStream.store(.init(
            accessToken: UUID().uuidString,
            refreshToken: UUID().uuidString,
            expiration: expiration
        ))
    }

    func testRefreshOnError() async throws {
        try await refreshingHelper(signedInTokenExpiration: Date.distantFuture, forceRefresh: false) {
            let router = Self.mockRouter(type: .none)
            let request = try await self.sut.getHTTPRequestOnUnAuthorizedError(from: router)
            XCTAssertEqual(request, try router.asHTTPRequest(hostname: self.hostnameProvider.hostname(for: router)))
        }
    }

    func testHTTPRequestProvidingWithNoneAuthType() async throws {
        let router = Self.mockRouter(type: .none)
        let request = try await self.sut.getHTTPRequest(from: router)
        XCTAssertEqual(request, try router.asHTTPRequest(hostname: self.hostnameProvider.hostname(for: router)))
    }

    func testRefreshTokenOnHTTPRequest() async throws {
        try await refreshingHelper(signedInTokenExpiration: Date.distantFuture, forceRefresh: false) {
            let router = Self.mockRouter(type: .bearer(.accessToken))
            let request = try await self.sut.getHTTPRequestOnUnAuthorizedError(from: router)
            XCTAssertEqual(request, try router.asHTTPRequest(hostname: self.hostnameProvider.hostname(for: router)).withBearerToken(try self.tokenRepository.apiToken.accessToken))
        }
    }

    func testHTTPRequestProvidingWithAccessTokenAuthType() async throws {
        self.setLoggedIn(expiration: .distantFuture)
        let router = Self.mockRouter(type: .bearer(.accessToken))
        let request = try await self.sut.getHTTPRequest(from: router)
        XCTAssertEqual(request, try router.asHTTPRequest(hostname: self.hostnameProvider.hostname(for: router)).withBearerToken(try tokenRepository.apiToken.accessToken))
    }

    func testHTTPRequestProvidingWithAccessTokenNotLoggedIn() async throws {
        let router = Self.mockRouter(type: .bearer(.accessToken))
        do {
            _ = try await self.sut.getHTTPRequest(from: router)
            XCTFail("Error not thrown")
        } catch is NotLoggedInError {
            
        } catch {
            XCTFail("Wrong password thrown: \(error)")
        }
    }

    func testHTTPRequestProvidingWithRefreshTokenLoggedIn() async throws {
        self.setLoggedIn(expiration: .distantFuture)
        let router = Self.mockRouter(type: .bearer(.refreshToken))
        let request = try await self.sut.getHTTPRequest(from: router)
        XCTAssertEqual(request, try router.asHTTPRequest(hostname: self.hostnameProvider.hostname(for: router)).withBearerToken(try tokenRepository.apiToken.refreshToken))
    }

    func testHTTPRequestProvidingWithRefreshTokenNotLoggedIn() async throws {
        let router = Self.mockRouter(type: .bearer(.refreshToken))
        do {
            _ = try await self.sut.getHTTPRequest(from: router)
            XCTFail("Error not thrown")
        } catch is NotLoggedInError {
            
        } catch {
            XCTFail("Wrong password thrown: \(error)")
        }
    }

    static private func mockRouter(type: BearerAuthorizationType) -> BaseAPIRouter<String, String> {
        BaseAPIRouter(hostname: URL(string: "https://cleevio.com")!, path: "/blog", authType: type, body: "")
    }
}


extension BaseAPIToken: Codable {
    enum CodingKeys: CodingKey {
        case access
        case refresh
        case expiresInS
    }

    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        let expiresInSeconds = try container.decode(TimeInterval.self, forKey: .expiresInS)

        self.init(
            accessToken: try container.decode(String.self, forKey: CodingKeys.access),
            refreshToken: try container.decode(String.self, forKey: CodingKeys.refresh),
            expiration: dateProvider.currentDate().addingTimeInterval(expiresInSeconds)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .access)
        try container.encode(refreshToken, forKey: .refresh)
        try container.encode(expiration.timeIntervalSinceNow, forKey: .expiresInS)
    }
}

struct RefreshTokenRouter: APIRouter {
    struct Response: TokenAPIRouterResponse {
        let refreshParameter: String
        let expiresInSParameter: TimeInterval
        let accessParameter: String

        func asAPIToken() -> RouterBytesAuthentication.BaseAPIToken {
            BaseAPIToken(
                accessToken: accessParameter,
                refreshToken: refreshParameter,
                expiration: dateProvider.currentDate().addingTimeInterval(expiresInSParameter))
        }
    }

    var defaultHeaderFields: RouterBytes.HTTPFields { [:] }
    var hostname: URL { URL(string: "https://cleevio.com")! }
    var jsonDecoder: JSONDecoder = .init()
    var jsonEncoder: JSONEncoder = .init()
    var path: Path { "" }
    var authType: RouterBytes.BearerAuthorizationType { .bearer(.refreshToken) }

    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        try jsonDecoder.decode(type, from: data)
    }

    func encode(_ value: some Encodable) throws -> Data {
        try jsonEncoder.encode(value)
    }
}

extension RefreshTokenRouter: RefreshTokenAPIRouter {
    init(previousToken: BaseAPIToken) {
        self.init()
    }
}

@available(macOS 10.15.0, *)
extension RouterBytes.BearerAuthorizationType: APITokenAuthorizationType {
    public func authorizedRequest(request: HTTPRequest, with apiToken: BaseAPIToken) -> HTTPRequest {
        switch self {
        case let .bearer(tokenType):
            let token: String = switch tokenType {
            case .accessToken:
                apiToken.accessToken.description
            case .refreshToken:
                apiToken.refreshToken.description
            }

            return request.withBearerToken(token)
        case .none:
            return request
        }
    }

    public func authorizedRequest(request: HTTPRequest, with provider: some APITokenProvider<BaseAPIToken>) async throws -> HTTPRequest {
        switch self {
        case .bearer:
            let apiToken = try await provider.apiToken
            return authorizedRequest(request: request, with: apiToken)
        case .none:
            return request
        }
    }
}
