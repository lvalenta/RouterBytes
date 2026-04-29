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
        let error = ResponseValidationError(response: response, data: Data())
        XCTAssertEqual(error, nil)
    }

    func testInitWithStatusCode300() {
        let response = HTTPResponse(status: 300)
        let error = ResponseValidationError(response: response, data: Data())
        XCTAssertEqual(error, nil)
    }

    func testInitWithClientError() {
        let response = HTTPResponse(status: 401)
        let error = ResponseValidationError(response: response, data: Data())
        XCTAssertEqual(error?.status, .unauthorized)
    }

    func testInitWithServerError() {
        let response = HTTPResponse(status: 500)
        let error = ResponseValidationError(response: response, data: Data())
        XCTAssertEqual(error?.status.code, 500)
    }

    func testInitWithInformationalResponse() {
        let response = HTTPResponse(status: 100)
        let error = ResponseValidationError(response: response, data: Data())
        XCTAssertEqual(error?.status.code, 100)
    }

    func testInitWithBadRequest() {
        let urlResponse = HTTPResponse(status: 400)
        let responseValidationError = ResponseValidationError(response: urlResponse, data: Data())
        XCTAssertEqual(responseValidationError?.status, .badRequest)
    }

    func testInitWithUnauthorized() {
        let urlResponse = HTTPResponse(status: 401)
        let responseValidationError = ResponseValidationError(response: urlResponse, data: Data())
        XCTAssertEqual(responseValidationError?.status, .unauthorized)
    }

    func testInitWithAccessDenied() {
        let urlResponse = HTTPResponse(status: 403)
        let responseValidationError = ResponseValidationError(response: urlResponse, data: Data())
        XCTAssertEqual(responseValidationError?.status, .forbidden)
    }

    func testInitWithNotFound() {
        let urlResponse = HTTPResponse(status: 404)
        let responseValidationError = ResponseValidationError(response: urlResponse, data: Data())
        XCTAssertEqual(responseValidationError?.status, .notFound)
    }

    func testStatusPropertyReturnsStatusCode() {
        let status = HTTPResponse.Status(code: 429)
        let responseValidationError = ResponseValidationError(response: HTTPResponse(status: status), data: Data())

        XCTAssertEqual(responseValidationError?.status.code, status.code)
    }

    func testErrorDescriptionUnauthorized() {
        let error = ResponseValidationError(response: HTTPResponse(status: .unauthorized), data: Data())
        XCTAssertEqual(error?.errorDescription, "Unauthorized")
    }

    func testErrorDescriptionAccessDenied() {
        let error = ResponseValidationError(response: HTTPResponse(status: .forbidden), data: Data())
        XCTAssertEqual(error?.errorDescription, "Access denied")
    }

    func testErrorDescriptionClientErrorForUnhandledClientError() {
        let error = ResponseValidationError(response: HTTPResponse(status: 429), data: Data())
        XCTAssertEqual(error?.errorDescription, "Client Error 429")
    }

    func testErrorDescriptionInvalidResponseCodeForInformational() {
        let error = ResponseValidationError(response: HTTPResponse(status: 100), data: Data())
        XCTAssertEqual(error?.errorDescription, "Invalid response code")
    }

    func testDataIsStoredFromResponse() {
        let data = Data("error body".utf8)
        let error = ResponseValidationError(response: HTTPResponse(status: 400), data: data)
        XCTAssertEqual(error?.data, data)
    }

    func testDataIsStoredFromDirectInit() {
        let data = Data("error body".utf8)
        let error = ResponseValidationError(status: .badRequest, data: data)
        XCTAssertEqual(error.data, data)
    }

    func testDataIsEmptyWhenNotProvided() {
        let error = ResponseValidationError(response: HTTPResponse(status: 500), data: Data())
        XCTAssertEqual(error?.data, Data())
    }

}
