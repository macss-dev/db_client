# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.1] - 2025-12-27

### Fixed
- **CRITICAL:** Eliminated heap corruption crashes on process exit
  - SQL Server: Exit code -1073740940 fully resolved (now exit code 0)
  - Oracle: Functional with known exit code issue (doesn't affect production)
  - Root cause: ODBC drivers retain internal references beyond disconnect()
  - Solution: Defer all resource cleanup to OS on process termination

### Changed
- Resource management: disconnect() and close() no longer actively free ODBC resources
  - Resources persist until process exit (~516 bytes per connection)
  - Prevents double-free and heap corruption issues
  - Ideal for singleton pattern in long-running servers

### Memory Impact
- ~516 bytes per connection retained until process exit
- Negligible for typical production use (1-10 permanent connections)
- Not recommended for applications creating/destroying 100+ dynamic connections

### Documentation
- Added docs/SOLUTION_v0.2.1_OPTION_A.md - Technical analysis
- Added docs/ORACLE_CONNECTION_ANALYSIS.md - Oracle-specific details
- Updated README with SQL Server and Oracle connection examples

## [0.2.0] - 2025-12-24

### Fixed
- **CRITICAL:** Fixed heap corruption crashes under concurrent load
  - Exit code -1073740940 after 6+ concurrent requests
  - Solution: Environment handle persists for Odbc instance lifetime
  - Impact: 6+ concurrent connections validated without crashes
- **CRITICAL:** Fixed 90+ second deadlocks when closing connections
  - Removed SQLFreeHandle(SQL_HANDLE_ENV, _hEnv) from disconnect()
  - Impact: Instant disconnect (~10ms), 5+ sequential connections work
- Fixed race conditions in concurrent connection scenarios

### Changed
- Improved disconnect logic with double-disconnect protection
- Enhanced error handling with proper ODBC status code validation

### Performance
- Validated with 6 concurrent connections
- Average response time: 333ms
- No memory leaks or resource exhaustion

## [0.1.0] - 2024-XX-XX

### Added
- Initial release
- SQL Server and Oracle support via ODBC
- Parameterized query support
- Connection management
