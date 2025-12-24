# db_client

A Dart package for interacting with ODBC databases. It allows you to connect to ODBC data sources and execute SQL queries directly from your Dart applications.

This package is a fork of [dart_odbc](https://pub.dev/packages/dart_odbc).

[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

## 🎉 v0.1.1 - Production Stability Release

**Critical fixes for concurrent operations:**
- ✅ Fixed deadlock causing 90+ second hangs on disconnect
- ✅ Fixed memory leak causing allocation failures
- ✅ Validated under concurrent load (6+ simultaneous connections)

See [PRODUCTION_FIXES_v0.1.1.md](docs/PRODUCTION_FIXES_v0.1.1.md) for technical details.

## Quick Start

### 1. Configure the connection

Create a `.env` file with your credentials:

```
SERVER=localhost
DATABASE=your_database
USERNAME=username
PASSWORD=password
DRIVER=ODBC Driver 17 for SQL Server
```

### 2. Create a repository

Use `DbClientConfig` and `SqlDbClient` to define your connection:

```dart
final config = DbClientConfig(
  server: 'localhost',
  database: 'your_database',
  username: 'username',
  password: 'password',
  driver: 'ODBC Driver 17 for SQL Server',
  additionalParams: {
    'Encrypt': 'no',  // Required for ODBC Driver 17+
    'TrustServerCertificate': 'yes',
  },
);

final client = SqlDbClient(config);
```

### 3. Execute queries

```dart
final response = await client.send(
  DbRequest.query('SELECT DB_NAME() AS database_name'),
);

if (response.success) {
  final result = response.firstOrNull;
  print(result);
}
```

### 4. Use parameterized queries

To prevent SQL injection, use parameters:

```dart
await client.send(
  DbRequest.query(
    'SELECT * FROM USERS WHERE UID = ?',
    params: [1],
  ),
);
```

### 5. Always close connections

**Important:** Always call `close()` to release ODBC resources:

```dart
try {
  final response = await client.send(
    DbRequest.query('SELECT * FROM users'),
  );
  // ... use response ...
} finally {
  await client.close();  // ✅ Always cleanup
}
```

## Features

- **Production-ready**: Validated under concurrent load (v0.1.1+)
- **Easy connection**: Configure credentials once
- **Parameterized queries**: SQL injection prevention
- **Clean abstraction**: Simple API with `DbClient` and `DbRequest`
- **Error handling**: Structured responses with success status
- **Resource management**: Proper ODBC handle lifecycle management

## Supported Databases

- Microsoft SQL Server
- Oracle
- Any database with an available ODBC driver

For more information about ODBC, check the [official Microsoft documentation](https://learn.microsoft.com/en-us/sql/odbc/microsoft-open-database-connectivity-odbc?view=sql-server-ver16)
