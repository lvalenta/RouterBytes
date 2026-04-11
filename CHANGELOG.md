# RouterBytes Changelog

## [1.0.0] - 2026-04-11
- Migrated RouterBytes networking primitives to Swift HTTP Types (`HTTPRequest`, `HTTPResponse`, `HTTPFields`, `HTTPMethod`).
- Updated Router/Service/Provider/Delegate APIs to use HTTP Types end-to-end.
- Improved `ResponseValidationError` to use `HTTPResponse.Status`.
- Kept first-class `HeaderResponse` support in the migrated HTTP Types flow.
- Added `RetryOptions.retryOnInternalError` and enabled it in `RetryOptions.default`.
- Added migration documentation for `0.10.x -> 1.0.0` (`MIGRATION.md`).

## [0.10.1] - 2026-03-30
- Fixed unchecked `Sendable` for Xcode 16.4.

## [0.10.0] - 2026-03-29
- Added retry mechanism options on `APIRouter`.

## [0.9.2] - 2026-02-26
- Refactored `RefreshableTokenProvider` suspension handling.
- Fixed tests.

## [0.9.1] - 2026-02-26
- Fixed actor reentrancy race conditions in token refresh flow.
- Restored docs.
- Added Swift CI workflow.

## [0.9.0] - 2025-02-12
- Fully support Swift 6 compilation mode.
- Require Response `T` in `APIServiceEventDelegate` to be `Sendable`
- Support Ordered `QueryItems` in `APIRouter`

## [0.8.1] - 2024-12-10
- Allow override `APIRouter.asURL(hostname:)`.
- Mapped `NSURLErrorCancelled` to `CancellationError`.
- Mapped `NSURLErrorNotConnectedToInternet` (code: `-1009`) to `URLError(.notConnectedToInternet)`.

## [0.8.0] - 2024-09-16
- Renamed to RouterBytes, initial release.


## [0.7.1] - 2024-09-04
- Added support for HeaderResponse
- Added support for watchOS.

## [0.6.2] - 2024-06-20
- Swift 6 Sendability improvements
