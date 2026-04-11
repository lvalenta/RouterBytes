# RouterBytes Migration Guide

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

If your app directly references these types, add imports:

```swift
import HTTPTypes
import HTTPTypesFoundation
```

### 2. Update `APIRouter` Conformance

Header-related API names were aligned with HTTP Types:

| 0.10.x | 1.0.0 |
| --- | --- |
| `defaultHeaders` | `defaultHeaderFields` |
| `additionalHeaders` | `additionalHeaderFields` |
| `headers` | `headerFields` |
| `asURLRequest(hostname:)` | `asHTTPRequest(hostname:)` |
| `asURLRequest()` | `asHTTPRequest()` |

`cachePolicy` is no longer part of `APIRouter`.

### 3. Update Service/Provider Signatures

`URLRequestProvider`, `APIServiceType`, `NetworkingServiceType`, and `APIServiceEventDelegate` now use `HTTPRequest`/`HTTPResponse`.

Notable signature changes:

- `getDataFromNetwork(for:)` -> `getDataFromNetwork(for:body:)`
- Delegate callbacks now include request body:
  - `requestFired(request:body:)`
  - `responseReceived(from:body:data:response:)`

### 4. Update Error Handling

`ResponseValidationError` changed from enum-style cases to a status-based struct:

- Old style:
  - `catch ResponseValidationError.unauthorized`
  - `catch let error as ResponseValidationError where error == .invalidResponseCode`
- New style:
  - `catch let error as ResponseValidationError where error.status == .unauthorized`
  - `catch let error as ResponseValidationError where error.status.kind == .informational || error.status.kind == .invalid`

### 5. Retry Behavior

`RetryOptions` now includes:

```swift
.retryOnInternalError
```

`RetryOptions.default` now retries on:

- timeout
- invalid/informational response codes
- internal/server errors (`5xx`)

If you need old behavior, set `retryOptions` explicitly.

### 6. Header Response Support

`HeaderResponse` support remains available in `1.0.0` and now decodes from `HTTPResponse.headerFields`.

No change is required to the `associatedtype HeaderResponse` declaration itself, but any custom code consuming raw response objects should switch to `HTTPResponse`.

## Quick Checklist

1. Rename `defaultHeaders` / `additionalHeaders` usages.
2. Replace `URLRequest`/`URLResponse` in RouterBytes integration points with `HTTPRequest`/`HTTPResponse`.
3. Update delegate and networking function signatures to include `body`.
4. Migrate `ResponseValidationError` checks to `status`/`status.kind`.
5. Decide whether to keep default retry behavior with `retryOnInternalError` enabled.
