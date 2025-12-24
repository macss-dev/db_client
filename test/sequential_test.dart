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

/// Test SECUENCIAL de múltiples conexiones (una después de otra)
void main() {
  test('5 conexiones SECUENCIALES', () async {
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

    stdout.writeln('\n${"=" * 60}');
    stdout.writeln('TEST: 5 CONEXIONES SECUENCIALES');
    stdout.writeln('Una conexión a la vez, cierra antes de abrir la siguiente');
    stdout.writeln("=" * 60);

    final stopwatch = Stopwatch()..start();

    // Ejecutar 5 conexiones UNA DESPUÉS DE OTRA
    for (int i = 0; i < 5; i++) {
      stdout.writeln('');
      stdout.writeln('[$i] Creando cliente...');
      final client = SqlDbClient(config);
      
      stdout.writeln('[$i] Imprimiendo connection string:');
      stdout.writeln('     ${config.connectionString.replaceAll(RegExp(r'PWD=[^;]+'), 'PWD=***')}');
      
      try {
        stdout.writeln('[$i] Ejecutando query...');
        final response = await client.send(
          DbRequest.query(
            'SELECT $i AS connection_id',
            errorMessage: 'Error en query $i',
          ),
        );

        if (!response.success) {
          stderr.writeln('[$i] ❌ ERROR: ${response.error}');
          fail('Query $i falló: ${response.error}');
        }

        final connectionId = response.rows.first['connection_id'];
        stdout.writeln('[$i] ✓ Query exitosa - connection_id: $connectionId');
      } catch (e, stack) {
        stderr.writeln('[$i] ❌ EXCEPTION: $e');
        stderr.writeln('Stack trace: $stack');
        rethrow;
      } finally {
        stdout.writeln('[$i] Cerrando conexión...');
        await client.close();
        stdout.writeln('[$i] 🔌 Conexión cerrada');
      }
    }

    stopwatch.stop();
    stdout.writeln('\n${"=" * 60}');
    stdout.writeln('✅ TEST EXITOSO');
    stdout.writeln('   Tiempo total: ${stopwatch.elapsedMilliseconds}ms');
    stdout.writeln('   Promedio por conexión: ${stopwatch.elapsedMilliseconds / 5}ms');
    stdout.writeln("=" * 60);
  });
}
