# db_client

A **production-ready** Dart package for connecting to SQL Server, Oracle, and PostgreSQL via ODBC. Battle-tested for concurrent workloads and long-running servers.

Forked from [dart_odbc](https://pub.dev/packages/dart_odbc), enhanced for production stability.

[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

## Version 0.2.1

**Fixes:**
- Eliminates heap corruption crashes on process exit
- SQL Server: Exit code 0 (fully resolved)
- Oracle: Functional, known exit code issue (doesn't affect production)

**Memory Strategy:**  
Resources persist until process termination to prevent ODBC driver cleanup issues. Impact: ~516 bytes per connection.

**Ideal for:** Long-running servers with singleton pattern (1-10 permanent connections).

## Quick Start

### SQL Server

```dart
import 'package:db_client/db_client.dart';

final client = SqlDbClient(DbClientConfig(
  driver: 'ODBC Driver 17 for SQL Server',
  server: 'localhost',
  database: 'my_database',
  username: 'sa',
  password: 'password',
  additionalParams: {
    'Encrypt': 'no',
    'TrustServerCertificate': 'yes',
  },
));

// Execute query
final result = await client.send(
  DbRequest.query('SELECT * FROM users WHERE id = ?', params: [1]),
);

if (result.success) {
  print(result.rows);
}
```

### Oracle

```dart
final client = SqlDbClient(DbClientConfig(
  driver: 'Oracle in instantclient_21_17',
  server: '',  // Leave empty
  port: 0,
  username: 'system',
  password: 'password',
  additionalParams: {
    'DBQ': 'localhost:1521/XEPDB1',  // host:port/service
  },
));

final result = await client.send(
  DbRequest.query('SELECT * FROM users WHERE id = ?', params: [1]),
);
```

### PostgreSQL

Functional, but not testted in production.

## Resource Management (v0.2.1+)

The `close()` method is **optional**. Resources are automatically cleaned up on process exit.

**Recommended pattern:**
```dart
// Singleton - never call close()
class Database {
  static SqlDbClient? _instance;
  
  static SqlDbClient get instance {
    _instance ??= SqlDbClient(config);
    return _instance!;
  }
}
```

**Memory impact:** ~516 bytes per connection retained until process exit.

## Features

- **SQL Server**: Full support (ODBC Driver 17+)
- **Oracle**: Full support (Instant Client 19c/21c)
- **PostgreSQL**: Coming soon
- **Parameterized queries**: SQL injection prevention
- **Concurrent connections**: Tested with 6+ simultaneous connections
- **Production-ready**: Ideal for long-running servers

## Additional Information

For more about ODBC, see the [Microsoft ODBC documentation](https://learn.microsoft.com/en-us/sql/odbc/microsoft-open-database-connectivity-odbc?view=sql-server-ver16).

