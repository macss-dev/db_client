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

/// Test simple para verificar que las conexiones se cierran correctamente
void main() {
  test('Simple connection test', () async {
    // Cargar variables del archivo .env
    final env = loadDotEnv('.env');

    stdout
      ..writeln('Configurando conexión...')
      ..writeln('Server: ${env['MSSQL_SERVER']}')
      ..writeln('Username: ${env['MSSQL_USERNAME']}')
      ..writeln('Driver: ${env['MSSQL_DRIVER']}');

    // Usar la misma configuración que en producción (mssql_repository.dart)
    final config = DbClientConfig(
      server: env['MSSQL_SERVER'] ?? 'localhost',
      username: env['MSSQL_USERNAME'] ?? 'sa',
      password: env['MSSQL_PASSWORD'] ?? 'Password123!',
      driver: env['MSSQL_DRIVER'] ?? 'ODBC Driver 17 for SQL Server',
      additionalParams: {
        'Encrypt':
            'no', // Deshabilitar encriptación para evitar error con ODBC Driver 17
        'TrustServerCertificate':
            'yes', // Confiar en el certificado del servidor
      },
    );

    stdout.writeln('Creando cliente...');
    final client = SqlDbClient(config);

    try {
      stdout.writeln('Enviando query...');
      final response = await client.send(
        DbRequest.query(
          'SELECT 1 AS test',
          errorMessage: 'Error en query',
        ),
      );

      stdout
        ..writeln('Response success: ${response.success}')
        ..writeln('Response rows: ${response.rows}')
        ..writeln('Response error: ${response.error}');

      if (!response.success) {
        stderr.writeln('❌ ERROR: ${response.error}');
      }

      expect(response.success, isTrue);
    } finally {
      stdout.writeln('Cerrando conexión...');
      await client.close();
      stdout.writeln('✓ Conexión cerrada');
    }
  });
}
