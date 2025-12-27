import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:test/test.dart';

/// Loads environment variables from a .env file
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

/// Test de SOLO 2 conexiones secuenciales
void main() {
  test('2 conexiones secuenciales', () async {
    final env = loadDotEnv('.env');
    
    final config = DbClientConfig(
      server: env['MSSQL_SERVER'] ?? 'localhost',
      username: env['MSSQL_USERNAME'] ?? 'sa',
      password: env['MSSQL_PASSWORD'] ?? 'Password123!',
      driver: env['MSSQL_DRIVER'] ?? 'ODBC Driver 17 for SQL Server',
      additionalParams: {
        'Encrypt': 'no',
        'TrustServerCertificate': 'yes',
      },
    );

    stdout.writeln('\n=== PRIMERA CONEXIÓN ===');
    stdout.writeln('Creando cliente 1...');
    final client1 = SqlDbClient(config);
    
    try {
      stdout.writeln('Ejecutando query 1...');
      final response1 = await client1.send(
        DbRequest.query('SELECT 1 AS test', errorMessage: 'Error en query 1'),
      );
      
      stdout.writeln('Response 1 success: ${response1.success}');
      if (!response1.success) {
        stderr.writeln('ERROR 1: ${response1.error}');
      }
      expect(response1.success, isTrue);
    } finally {
      stdout.writeln('Cerrando cliente 1...');
      await client1.close();
      stdout.writeln('✓ Cliente 1 cerrado\n');
    }

    // Esperar un poco antes de la segunda conexión
    await Future<void>.delayed(const Duration(milliseconds: 500));

    stdout.writeln('=== SEGUNDA CONEXIÓN ===');
    stdout.writeln('Creando cliente 2...');
    final client2 = SqlDbClient(config);
    
    try {
      stdout.writeln('Ejecutando query 2...');
      final response2 = await client2.send(
        DbRequest.query('SELECT 2 AS test', errorMessage: 'Error en query 2'),
      );
      
      stdout.writeln('Response 2 success: ${response2.success}');
      if (!response2.success) {
        stderr.writeln('ERROR 2: ${response2.error}');
      }
      expect(response2.success, isTrue);
    } finally {
      stdout.writeln('Cerrando cliente 2...');
      await client2.close();
      stdout.writeln('✓ Cliente 2 cerrado\n');
    }

    stdout.writeln('✅ TEST COMPLETADO - 2 conexiones secuenciales exitosas');
  });
}
