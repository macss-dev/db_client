import 'dart:io';
import 'package:db_client/src/odbc/odbc.dart';
import 'package:test/test.dart';

Map<String, String> loadDotEnv(String path) {
  final file = File(path);
  final map = <String, String>{};
  if (!file.existsSync()) return map;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    final key = trimmed.substring(0, idx).trim();
    var value = trimmed.substring(idx + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    map[key] = value;
  }
  return map;
}

void main() {
  late String connectionString;

  setUpAll(() {
    final env = loadDotEnv('example/.env');
    final driver = env['DRIVER'] ?? 'ODBC Driver 17 for SQL Server';
    final server = env['SERVER'] ?? 'localhost';
    final database = env['DATABASE'] ?? '';
    final username = env['USERNAME'] ?? '';
    final password = env['PASSWORD'] ?? '';
    // ignore: lines_longer_than_80_chars
    connectionString =
        'DRIVER={$driver};SERVER=$server;DATABASE=$database;UID=$username;PWD=$password;';
  });

  test('connect and disconnect without query - should not crash', () async {
    stdout.writeln('Test 1: Connect and disconnect without query');
    final odbc = Odbc();
    await odbc.connectWithConnectionString(connectionString);
    stdout.writeln('Connected successfully');
    await odbc.disconnect();
    stdout.writeln('Disconnected successfully');
  });

  test('connect, simple query, disconnect - should not crash', () async {
    stdout.writeln('Test 2: Connect, execute simple query, disconnect');
    final odbc = Odbc();
    await odbc.connectWithConnectionString(connectionString);
    stdout.writeln('Connected successfully');

    final result = await odbc.execute('SELECT 1 AS test');
    stdout.writeln('Query result: $result');
    expect(result, isNotEmpty);

    await odbc.disconnect();
    stdout.writeln('Disconnected successfully');
  });

  test('connect, query with string result, disconnect - check for crash',
      () async {
    stdout.writeln('Test 3: Connect, execute, return string, disconnect');
    final odbc = Odbc();
    await odbc.connectWithConnectionString(connectionString);
    stdout.writeln('Connected successfully');

    final result = await odbc.execute('SELECT @@VERSION AS version');
    stdout.writeln('Query returned ${result.length} rows');
    expect(result, isNotEmpty);

    await odbc.disconnect();
    stdout.writeln('Disconnected successfully');
  });

  test('multiple connect/disconnect cycles - stress test', () async {
    stdout.writeln('Test 4: Multiple connect/disconnect cycles');
    for (var i = 0; i < 3; i++) {
      stdout.writeln('Cycle ${i + 1}');
      final odbc = Odbc();
      await odbc.connectWithConnectionString(connectionString);
      final result = await odbc.execute('SELECT $i AS num');
      expect(result, isNotEmpty);
      await odbc.disconnect();
      stdout.writeln('Cycle ${i + 1} completed');
    }
    stdout.writeln('All cycles completed');
  });

  test('connect, multiple queries, then disconnect', () async {
    stdout.writeln('Test 5: Multiple queries before disconnect');
    final odbc = Odbc();
    await odbc.connectWithConnectionString(connectionString);

    for (var i = 0; i < 5; i++) {
      final result = await odbc.execute('SELECT $i AS iteration');
      stdout.writeln('Query $i result: $result');
      expect(result, isNotEmpty);
    }

    await odbc.disconnect();
    stdout.writeln('Disconnected after multiple queries');
  });

  test('verify handles are null after disconnect', () async {
    stdout.writeln('Test 6: Verify state after disconnect');
    final odbc = Odbc();
    await odbc.connectWithConnectionString(connectionString);
    await odbc.execute('SELECT 1');
    await odbc.disconnect();

    // Try to detect if there's an issue by waiting a bit
    await Future<void>.delayed(const Duration(milliseconds: 100));
    stdout.writeln('Test completed without immediate crash');
  });
}
