# Changelog
All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.1] - 2025-12-24
### Fixed
- **CRITICAL:** Fixed deadlock in `disconnect()` when creating multiple sequential connections
  - Removed premature `_hEnv` handle cleanup that caused 90+ second hangs
  - ODBC environment handle now persists for the lifetime of the `Odbc` instance
  - Fixes production crashes after 6+ concurrent requests
- Fixed memory leak in `execute()` method
  - Added missing `calloc.free(pHStmt)` to prevent "Memory allocation failure" errors
  - Prevents resource exhaustion under load
- Improved error handling in `disconnect()` with proper status code validation

### Changed
- Added double-disconnect protection with `_disconnected` flag
- Enhanced disconnect logging for troubleshooting

### Testing
- ✅ Validated 5+ sequential connections (240ms avg per connection)
- ✅ Validated 6+ concurrent connections
- ✅ No heap corruption or access violations under load

## [0.1.0] - 2025-12-09
### Added
- Initial release of **db_client**
- `DbClient` interface and `SqlDbClient` implementation for clean database access
- `DbRequest` for building queries with parameters
- `DbResponse` for structured query responses
- `DbClientConfig` for connection configuration
- Support for parameterized queries (SQL injection prevention)
- Connection management with lazy initialization
- Support for ODBC databases: SQL Server, Oracle, and others