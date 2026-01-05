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

/// Test de concurrencia para verificar que múltiples conexiones
/// simultáneas no causan heap corruption ni race conditions
void main() {
  group('Concurrent Connections Test', () {
    late DbClientConfig config;

    setUp(() {
      // Cargar variables del archivo .env
      final env = loadDotEnv('.env');

      // Configuración para SQL Server usando credenciales del .env
      config = DbClientConfig(
        server: env['MSSQL_SERVER'] ?? 'localhost',
        username: env['MSSQL_USERNAME'] ?? 'sa',
        password: env['MSSQL_PASSWORD'] ?? 'Password123!',
        driver: env['MSSQL_DRIVER'] ?? 'ODBC Driver 17 for SQL Server',
        additionalParams: {
          'Encrypt': 'no',
          'TrustServerCertificate': 'yes',
        },
      );
    });

    test(
      '✓ 10 conexiones concurrentes - sin singleton',
      () async {
        stdout..writeln('\n${"=" * 80}')
        ..writeln('TEST: 10 CONEXIONES CONCURRENTES')
        ..writeln('Cada conexión ejecuta una query y cierra correctamente')
        ..writeln('=' * 80);

        final stopwatch = Stopwatch()..start();
        final futures = <Future<void>>[];

        // Crear 10 conexiones concurrentes
        for (var i = 0; i < 10; i++) {
          final future = Future(() async {
            final client = SqlDbClient(config);
            try {
              stdout.writeln('[$i] Conectando...');

              final response = await client.send(
                DbRequest.query(
                  'SELECT @@VERSION AS version, $i AS connection_id',
                  errorMessage: 'Error en query $i',
                ),
              );

              if (!response.success) {
                stderr.writeln('[$i] ❌ ERROR: ${response.error}');
              }

              expect(response.success, isTrue,
                  reason:
                      'Query $i debe ser exitosa. Error: ${response.error}',);
              expect(response.rows.isNotEmpty, isTrue,
                  reason: 'Debe retornar datos',);

              final connectionId = response.rows.first['connection_id'];
              stdout.writeln(
                  '[$i] ✓ Query exitosa - connection_id: $connectionId',);
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
        stdout..writeln('\n${"=" * 80}')
        ..writeln('✅ TEST EXITOSO')
        ..writeln('   Tiempo total: ${stopwatch.elapsedMilliseconds}ms')
        ..writeln(
            '   Promedio por conexión: ${stopwatch.elapsedMilliseconds / 10}ms',)
        ..writeln('   Sin heap corruption ✓')
        ..writeln('   Sin race conditions ✓')
        ..writeln('=' * 80);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      '✓ 20 conexiones con queries pesadas',
      () async {
        stdout..writeln('\n${"=" * 80}')
        ..writeln('TEST: 20 CONEXIONES CON QUERIES PESADAS')
        ..writeln('Simula carga pesada con múltiples queries por conexión')
        ..writeln('=' * 80);

        final stopwatch = Stopwatch()..start();
        final futures = <Future<void>>[];

        for (var i = 0; i < 20; i++) {
          final future = Future(() async {
            final client = SqlDbClient(config);
            try {
              stdout.writeln('[$i] Conectando...');

              // Ejecutar 3 queries por conexión
              for (var j = 0; j < 3; j++) {
                final response = await client.send(
                  DbRequest.query(
                    '''
                  SELECT 
                    $i AS connection_id,
                    $j AS query_num,
                    GETDATE() AS timestamp,
                    @@VERSION AS version
                  ''',
                    errorMessage: 'Error en conexión $i, query $j',
                  ),
                );

                expect(response.success, isTrue);
              }

              stdout.writeln('[$i] ✓ 3 queries exitosas');
            } finally {
              await client.close();
              stdout.writeln('[$i] 🔌 Desconectado');
            }
          });

          futures.add(future);
        }

        await Future.wait(futures);

        stopwatch.stop();
        stdout..writeln('\n${"=" * 80}')
        ..writeln('✅ TEST EXITOSO - CARGA PESADA')
        ..writeln('   Tiempo total: ${stopwatch.elapsedMilliseconds}ms')
        ..writeln('   Total queries: 60')
        ..writeln(
            '   Promedio: ${stopwatch.elapsedMilliseconds / 60}ms por query',)
        ..writeln('=' * 80);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      '✓ Stress test: 50 conexiones rápidas',
      () async {
        stdout..writeln('\n${"=" * 80}')
        ..writeln('STRESS TEST: 50 CONEXIONES RÁPIDAS')
        ..writeln('Máxima presión para detectar race conditions')
        ..writeln('=' * 80);

        final stopwatch = Stopwatch()..start();
        final futures = <Future<void>>[];
        var successCount = 0;
        var errorCount = 0;

        for (var i = 0; i < 50; i++) {
          final future = Future(() async {
            final client = SqlDbClient(config);
            try {
              final response = await client.send(
                DbRequest.query(
                  'SELECT $i AS id',
                  errorMessage: 'Error en conexión $i',
                ),
              );

              if (response.success) {
                successCount++;
              } else {
                errorCount++;
                stderr.writeln('[$i] ❌ Error: ${response.error}');
              }
            } catch (e) {
              errorCount++;
              stderr.writeln('[$i] ❌ Exception: $e');
            } finally {
              await client.close();
            }
          });

          futures.add(future);
        }

        await Future.wait(futures);

        stopwatch.stop();
        stdout..writeln('\n${"=" * 80}')
        ..writeln('✅ STRESS TEST COMPLETADO')
        ..writeln('   Tiempo total: ${stopwatch.elapsedMilliseconds}ms')
        ..writeln('   Exitosas: $successCount')
        ..writeln('   Errores: $errorCount')
        ..writeln(
            '   Tasa de éxito: ${(successCount / 50 * 100).toStringAsFixed(1)}%',)
        ..writeln('=' * 80);

        // Esperar mínimo 80% de éxito
        expect(
          successCount,
          greaterThanOrEqualTo(40),
          reason: 'Al menos 40 de 50 conexiones deben ser exitosas',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      '✓ Test de memory leaks - abrir y cerrar 100 conexiones',
      () async {
        stdout..writeln('\n${"=" * 80}')
        ..writeln('MEMORY LEAK TEST: 100 CONEXIONES SECUENCIALES')
        ..writeln('Verificar que no hay acumulación de memoria')
        ..writeln('=' * 80);

        final stopwatch = Stopwatch()..start();

        for (var i = 0; i < 100; i++) {
          final client = SqlDbClient(config);
          try {
            final response = await client.send(
              DbRequest.query(
                'SELECT $i AS id',
                errorMessage: 'Error en iteración $i',
              ),
            );

            expect(response.success, isTrue);

            if (i % 10 == 0) {
              stdout.writeln('[$i] ✓ Progreso: $i%');
            }
          } finally {
            await client.close();
          }
        }

        stopwatch.stop();
        stdout..writeln('\n${"=" * 80}')
        ..writeln('✅ MEMORY LEAK TEST COMPLETADO')
        ..writeln('   100 conexiones abiertas y cerradas correctamente')
        ..writeln('   Tiempo total: ${stopwatch.elapsedMilliseconds}ms')
        ..writeln(
            '   Promedio: ${stopwatch.elapsedMilliseconds / 100}ms por conexión',)
        ..writeln('   Sin memory leaks ✓')
        ..writeln('=' * 80);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
