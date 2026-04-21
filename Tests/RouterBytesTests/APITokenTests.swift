//
//  APITokenTests.swift
//
//
//  Created by Lukáš Valenta on 02.05.2023.
//

import XCTest
import RouterBytesAuthentication

final class ApiTokenTests: XCTestCase {
    func testAccessTokenExpiresNow() {
        let now = Date()
        let expirationDate = now
        let apitoken = BaseAPIToken(accessToken: "", refreshToken: "", expiration: expirationDate)

        XCTAssertEqual(apitoken.accessTokenState(currentDate: now), .activeShouldAttemptRefresh)
    }

    func testAccessTokenExpiresNowInAMinute() {
        let now = Date()
        let expirationDate = now.addingTimeInterval(60)
        let apitoken = BaseAPIToken(accessToken: "", refreshToken: "", expiration: expirationDate)

        XCTAssertEqual(apitoken.accessTokenState(currentDate: now), .activeShouldAttemptRefresh)
    }

    func testAccessTokenExpired() {
        let now = Date()
        let expirationDate = now.addingTimeInterval(-60)
        let apitoken = BaseAPIToken(accessToken: "", refreshToken: "", expiration: expirationDate)

        XCTAssertEqual(apitoken.accessTokenState(currentDate: now), .expired)
    }

    func testAccessTokenExpiredInDistantPast() {
        let now = Date()
        let expirationDate = Date.distantPast
        let apitoken = BaseAPIToken(accessToken: "", refreshToken: "", expiration: expirationDate)

        XCTAssertEqual(apitoken.accessTokenState(currentDate: now), .expired)
    }

    func testAccessTokenExpiresNowIn299Seconds() {
        let now = Date()
        let expirationDate = now.addingTimeInterval(299)
        let apitoken = BaseAPIToken(accessToken: "", refreshToken: "", expiration: expirationDate)

        XCTAssertEqual(apitoken.accessTokenState(currentDate: now), .activeShouldAttemptRefresh)
    }

    func testAccessTokenExpiresNowIn5Minutes() {
        let now = Date()
        let expirationDate = now.addingTimeInterval(300)
        let apitoken = BaseAPIToken(accessToken: "", refreshToken: "", expiration: expirationDate)

        XCTAssertEqual(apitoken.accessTokenState(currentDate: now), .active)
    }

    func testAccessTokenExpiresNowIn10Minutes() {
        let now = Date()
        let expirationDate = now.addingTimeInterval(600)
        let apitoken = BaseAPIToken(accessToken: "", refreshToken: "", expiration: expirationDate)

        XCTAssertEqual(apitoken.accessTokenState(currentDate: now), .active)
    }

    func testAccessTokenExpiresNowInDistantFuture() {
        let now = Date()
        let expirationDate = Date.distantFuture
        let apitoken = BaseAPIToken(accessToken: "", refreshToken: "", expiration: expirationDate)

        XCTAssertEqual(apitoken.accessTokenState(currentDate: now), .active)
    }
}
