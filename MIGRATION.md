# RouterBytes Migration Guide

## Migrating to 1.0.1 from 1.0.0

`1.0.1` addresses an API change that was omitted from `1.0.0`. If you are upgrading from `0.10.x`, apply this section in addition to the `0.10.x -> 1.0.0` guide below.

### Access Token State

The boolean `needsToBeRefreshed(...)` APIs were replaced with a tri-state `AccessTokenState` so the refresh provider can distinguish between a token that is still valid but approaching expiration and one that has already expired.

```swift
public enum AccessTokenState: Sendable {
    case expired
    case activeShouldAttemptRefresh
    case active
}
```

| 1.0.0 | 1.0.1 |
| --- | --- |
| `RefreshableAPITokenType.needsToBeRefreshed(currentDate:maximumTimeUntilExpiration:) -> Bool` | `RefreshableAPITokenType.accessTokenState(currentDate:) -> AccessTokenState` |
| `RefreshableAPITokenType.needsToBeRefreshed(currentDate:) -> Bool` | removed — call `accessTokenState(currentDate:)` |
| `RefreshTokenProvider.tokenNeedsToBeRefreshed(currentToken:) -> Bool` | `RefreshTokenProvider.accessTokenState(currentToken:) -> AccessTokenState` |

Update any custom `RefreshableAPITokenType` or `RefreshTokenProvider` conformances:

```swift
// 1.0.0
public func needsToBeRefreshed(currentDate: Date, maximumTimeUntilExpiration: TimeInterval) -> Bool {
    expiration < currentDate.advanced(by: maximumTimeUntilExpiration)
}

// 1.0.1
public func accessTokenState(currentDate: Date) -> AccessTokenState {
    if expiration < currentDate { return .expired }
    return expiration < currentDate.advanced(by: 300) ? .activeShouldAttemptRefresh : .active
}
```

### Refresh Semantics

`RefreshableTokenProvider` now acts on the new state:

- `.expired` — refresh is mandatory. A failure is propagated to callers as `FailedWithUnAuthorizedError`.
- `.activeShouldAttemptRefresh` — refresh is attempted proactively. If it fails, the current (still valid) token is returned and no error is thrown. The next `.expired` decision will surface the problem.
- `.active` — the current token is returned without contacting the refresh endpoint.

### Unauthorized Delegate Callbacks

`APIService.getData` tightened the catch clause around the unauthorized retry path so only `FailedWithUnAuthorizedError` is forwarded to `APIServiceEventDelegate.requestFailedWithUnAuthorizedError` on the retry attempt. Other errors thrown while re-issuing the request (e.g. transport failures, `ResponseValidationError` for non-401 statuses) propagate without invoking the unauthorized delegate callback.

## Migrating to 1.0.0 from 0.10.x

`1.0.0` migrates RouterBytes networking primitives to Swift HTTP Types and keeps first-class support for `HeaderResponse`.

### 1. Update Core HTTP Types

RouterBytes now uses `swift-http-types` abstractions across request/response APIs.

| 0.10.x | 1.0.0 |
| --- | --- |
| `URLRequest` | `HTTPRequest` |
| `URLResponse` / `HTTPURLResponse` | `HTTPResponse` |
| `Headers` (`[String: String]`) | `HTTPFields` |
| custom `HTTPMethod` struct | `HTTPRequest.Method` (`typealias HTTPMethod`) |

You do not need to import the types from HTTP Types.

### 2. Update `APIRouter` Conformance

Header-related API names were aligned with HTTP Types:

| 0.10.x | 1.0.0 |
| --- | --- |
| `defaultHeaders` | `defaultHeaderFields` |
| `additionalHeaders` | `additionalHeaderFields` |
| `headers` | `headerFields` |
| `asURLRequest(hostname:)` | `asHTTPRequest(hostname:)` |
| `asURLRequest()` | `asHTTPRequest()` |

Because of the change, Headers are no longer `Dictionary` of string key, but they can be represented as a `Dictionary` of `HTTPField.Name` and value of `String`. Extend `HTTPField.Name` to support it.

`cachePolicy` is no longer part of `APIRouter`. Use `URLSessionConfiguration` instead.

The default `AuthorizationType` on `APIRouter` changed from `AuthorizationType` to `BearerAuthorizationType`:

```swift
// 0.10.x
associatedtype AuthorizationType = RouterBytes.AuthorizationType

// 1.0.0
associatedtype AuthorizationType = RouterBytes.BearerAuthorizationType
```

### 3. Update Service/Provider Signatures

`URLRequestProvider`, `APIServiceType`, `NetworkingServiceType`, and `APIServiceEventDelegate` now use `HTTPRequest`/`HTTPResponse`.

Notable signature changes:

| 0.10.x | 1.0.0 |
| --- | --- |
| `URLRequestProvider` | `HTTPRequestProvider` |
| `BaseURLRequestProvider` | `BaseHTTPRequestProvider` |
| `MockURLRequestProvider` | `MockHTTPRequestProvider` |
| `getURLRequest(from:)` | `getHTTPRequest(from:)` |
| `getURLRequestOnUnAuthorizedError(from:)` | `getHTTPRequestOnUnAuthorizedError(from:)` |
| `APIRouterService(..., urlRequestProvider:, ...)` | `APIRouterService(..., httpRequestProvider:, ...)` |

- `getDataFromNetwork(for:)` -> `getDataFromNetwork(for:body:)`
- Delegate callbacks now include request body:
  - `requestFired(request:body:)`
  - `responseReceived(from:body:data:response:)`
- Unauthorized delegate callback now also includes the thrown error:
  - `requestFailedWithUnAuthorizedError(router:error:)`

### 4. Update Authorization Types

`AuthorizationType` was renamed and restructured:

| 0.10.x | 1.0.0 |
| --- | --- |
| `AuthorizationType` | `BearerAuthorizationType` |
| `AuthorizationType.BearerType` | `TokenAuthorizationType` |
| `.bearer(.accessToken)` | `.bearer(.accessToken)` (unchanged usage, new type) |

`APITokenAuthorizationType` is now a generic protocol with an associated type. The built-in conformance on `AuthorizationType` was removed — you must provide your own conformance:

```swift
// 0.10.x — conformance was provided automatically
// AuthorizationType: APITokenAuthorizationType ✅ out of the box

// 1.0.0 — provide your own conformance
extension BearerAuthorizationType: APITokenAuthorizationType {
    public func authorizedRequest(request: HTTPRequest, with apiToken: YourAPIToken) -> HTTPRequest {
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

    public func authorizedRequest(request: HTTPRequest, with provider: some APITokenProvider<YourAPIToken>) async throws -> HTTPRequest {
        switch self {
        case .bearer:
            let apiToken = try await provider.apiToken
            return authorizedRequest(request: request, with: apiToken)
        case .none:
            return request
        }
    }
}
```

`RefreshTokenAPIRouter.APIToken` and `TokenAPIRouterResponse.APIToken` no longer default to `BaseAPIToken`. You must specify the associated type explicitly, and it must match `AuthorizationType.APIToken`:

```swift
// 0.10.x
associatedtype APIToken: RefreshableAPITokenType = BaseAPIToken

// 1.0.0
associatedtype APIToken: RefreshableAPITokenType where APIToken == AuthorizationType.APIToken
```

`TokenProviderWrappedHTTPRequestProvider` now requires `AuthorizationType.APIToken == APITokenProvider.APIToken`.

### 5. Update Error Handling

`ResponseValidationError` changed from enum-style cases to a status-based struct:

- Old style:
  - `catch ResponseValidationError.unauthorized`
  - `catch let error as ResponseValidationError where error == .invalidResponseCode`
- New style:
  - `catch let error as ResponseValidationError where error.status == .unauthorized`
  - `catch let error as ResponseValidationError where error.status.kind == .informational || error.status.kind == .invalid`

### 6. Retry Behavior

`RetryOptions` now includes:

```swift
.retryOnInternalError
```

`RetryOptions.default` now retries on:

- timeout
- invalid/informational response codes
- internal/server errors (`5xx`)

If you need old behavior, set `retryOptions` explicitly.

### 7. Header Response Support

`HeaderResponse` support remains available in `1.0.0` and now decodes from `HTTPResponse.headerFields`.

No change is required to the `associatedtype HeaderResponse` declaration itself, but any custom code consuming raw response objects should switch to `HTTPResponse`.

## Quick Checklist

1. Rename `defaultHeaders` / `additionalHeaders` usages.
2. Replace `URLRequest`/`URLResponse` in RouterBytes integration points with `HTTPRequest`/`HTTPResponse`.
3. Rename request provider types/methods to `HTTPRequestProvider` (`getHTTPRequest(...)` APIs).
4. Update delegate and networking function signatures to include `body`.
5. Rename `AuthorizationType` to `BearerAuthorizationType` and `BearerType` to `TokenAuthorizationType`.
6. Provide your own `APITokenAuthorizationType` conformance on `BearerAuthorizationType` (or your custom type).
7. Remove reliance on default `= BaseAPIToken` — explicitly specify `APIToken` associated types.
8. Migrate `ResponseValidationError` checks to `status`/`status.kind`.
9. Decide whether to keep default retry behavior with `retryOnInternalError` enabled.
