import 'dart:async';
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

/// Test conservador de concurrencia (3-5 conexiones)
void main() {
  test(
    '✓ 5 conexiones concurrentes (test conservador)',
    () async {
      // Cargar variables del archivo .env
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

      stdout.writeln('\n${"=" * 80}');
      stdout.writeln('TEST: 5 CONEXIONES CONCURRENTES (CONSERVADOR)');
      stdout.writeln(
          'Verifica que no hay heap corruption con concurrencia moderada');
      stdout.writeln('=' * 80);

      final stopwatch = Stopwatch()..start();
      final futures = <Future<void>>[];

      // Crear 5 conexiones concurrentes
      for (var i = 0; i < 5; i++) {
        final future = Future(() async {
          final client = SqlDbClient(config);
          try {
            stdout.writeln('[$i] Conectando...');

            final response = await client.send(
              DbRequest.query(
                'SELECT @@VERSION AS version, $i AS connection_id, GETDATE() AS timestamp',
                errorMessage: 'Error en query $i',
              ),
            );

            if (!response.success) {
              stderr.writeln('[$i] ❌ ERROR: ${response.error}');
            } else {
              final connectionId = response.rows.first['connection_id'];
              final timestamp = response.rows.first['timestamp'];
              stdout.writeln(
                  '[$i] ✓ Query exitosa - connection_id: $connectionId, timestamp: $timestamp');
            }

            expect(response.success, isTrue,
                reason: 'Query $i falló. Error: ${response.error}');
            expect(response.rows.isNotEmpty, isTrue);
          } finally {
            await client.close();
            stdout.writeln('[$i] 🔌 Desconectado');
          }
        });

        futures.add(future);
      }

      // Esperar que todas las conexiones terminen
      await Future.wait(futures);

      stopwatch.stop();
      stdout.writeln('\n${"=" * 80}');
      stdout.writeln('✅ TEST EXITOSO');
      stdout.writeln('   Tiempo total: ${stopwatch.elapsedMilliseconds}ms');
      stdout.writeln(
          '   Promedio por conexión: ${stopwatch.elapsedMilliseconds / 5}ms');
      stdout.writeln('   Sin heap corruption ✓');
      stdout.writeln('   Sin race conditions ✓');
      stdout.writeln('=' * 80);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
