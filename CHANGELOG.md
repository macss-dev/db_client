# Changelog
All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

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