# Test Suite

## Essential Tests

### Core Functionality
- **simple_test.dart** - Basic connection and query execution
- **concurrent_connections_test.dart** - Multiple simultaneous connections
- **sequential_test.dart** - Sequential connection creation

### Database-Specific
- **oracle_connection_test.dart** - Oracle with DBQ parameter (20 queries)
- **realistic_workflow_mssql_only_test.dart** - SQL Server workload (20 queries)

### v0.2.1 Validation
- **option_a_validation_test.dart** - Memory management validation (50 queries)

### Advanced Features
- **connection_string_test.dart** - Connection string generation
- **username_password_test.dart** - Authentication patterns
- **incremental_sqlgetdata_test.dart** - Large data retrieval

## Running Tests

All tests:
```bash
dart test
```

Specific database:
```bash
dart test test/realistic_workflow_mssql_only_test.dart
dart test test/oracle_connection_test.dart
```

## Requirements

Create .env file:
```env
MSSQL_DRIVER=ODBC Driver 17 for SQL Server
MSSQL_SERVER=localhost
MSSQL_USERNAME=sa
MSSQL_PASSWORD=password

ORACLE_DRIVER=Oracle in instantclient_21_17
ORACLE_SERVER=localhost:1521/XEPDB1
ORACLE_USERNAME=system
ORACLE_PASSWORD=password
```

## Expected Results

**SQL Server:** Exit code 0, all queries successful  
**Oracle:** Queries successful, exit code -1073740791 (known, doesn't affect production)
