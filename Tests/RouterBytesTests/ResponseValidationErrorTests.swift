//
//  ResponseValidationErrorTests.swift
//  
//
//  Created by Lukáš Valenta on 01.05.2023.
//

import XCTest
import RouterBytes

final class ResponseValidationErrorTests: XCTestCase {
    
    func testInitWithValidResponse() {
        let response = HTTPResponse(status: 200)
        let error = ResponseValidationError(response: response)
        XCTAssertEqual(error, nil)
    }
    
    func testInitWithStatusCode300() {
        let response = HTTPResponse(status: 300)
        let error = ResponseValidationError(response: response)
        XCTAssertEqual(error, nil)
    }
    
    func testInitWithClientError() {
        let response = HTTPResponse(status: 401)
        let error = ResponseValidationError(response: response)
        XCTAssertEqual(error?.status, .unauthorized)
    }
    
    func testInitWithServerError() {
        let response = HTTPResponse(status: 500)
        let error = ResponseValidationError(response: response)
        XCTAssertEqual(error?.status.code, 500)
    }
    
    func testInitWithInformationalResponse() {
        let response = HTTPResponse(status: 100)
        let error = ResponseValidationError(response: response)
        XCTAssertEqual(error?.status.code, 100)
    }

    func testInitWithBadRequest() {
        let urlResponse = HTTPResponse(status: 400)
        let responseValidationError = ResponseValidationError(response: urlResponse)
        XCTAssertEqual(responseValidationError?.status, .badRequest)
    }

    func testInitWithUnauthorized() {
        let urlResponse = HTTPResponse(status: 401)
        let responseValidationError = ResponseValidationError(response: urlResponse)
        XCTAssertEqual(responseValidationError?.status, .unauthorized)
    }

    func testInitWithAccessDenied() {
        let urlResponse = HTTPResponse(status: 403)
        let responseValidationError = ResponseValidationError(response: urlResponse)
        XCTAssertEqual(responseValidationError?.status, .forbidden)
    }

    func testInitWithNotFound() {
        let urlResponse = HTTPResponse(status: 404)
        let responseValidationError = ResponseValidationError(response: urlResponse)
        XCTAssertEqual(responseValidationError?.status, .notFound)
    }

    func testStatusPropertyReturnsStatusCode() {
        let status = HTTPResponse.Status(code: 429)
        let responseValidationError = ResponseValidationError(response: HTTPResponse(status: status))

        XCTAssertEqual(responseValidationError?.status.code, status.code)
    }

    func testErrorDescriptionUnauthorized() {
        let error = ResponseValidationError(response: HTTPResponse(status: .unauthorized))
        XCTAssertEqual(error?.errorDescription, "Unauthorized")
    }

    func testErrorDescriptionAccessDenied() {
        let error = ResponseValidationError(response: HTTPResponse(status: .forbidden))
        XCTAssertEqual(error?.errorDescription, "Access denied")
    }

    func testErrorDescriptionClientErrorForUnhandledClientError() {
        let error = ResponseValidationError(response: HTTPResponse(status: 429))
        XCTAssertEqual(error?.errorDescription, "Client Error 429")
    }

    func testErrorDescriptionInvalidResponseCodeForInformational() {
        let error = ResponseValidationError(response: HTTPResponse(status: 100))
        XCTAssertEqual(error?.errorDescription, "Invalid response code")
    }

}
