import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:test/test.dart';

/// Test con connection string completa y explícita
void main() {
  test('Test con connection string explícita', () async {
    stdout.writeln('=== Test de Conexión SQL Server ===');
    
    // Connection string completa y explícita
    final connectionString = 'DRIVER={ODBC Driver 17 for SQL Server};'
        'SERVER=192.168.10.17,1433;'
        'DATABASE=master;'
        'UID=uu_firmaElectronica;'
        'PWD=nHmy34ePsUdz;'
        'Encrypt=no;'
        'TrustServerCertificate=yes;'
        'Connection Timeout=30;';
    
    stdout.writeln('Connection String: ${connectionString.replaceAll(RegExp(r'PWD=[^;]+'), 'PWD=***')}');
    
    final config = DbClientConfig(
      server: '192.168.10.17',
      username: 'uu_firmaElectronica',
      password: 'nHmy34ePsUdz',
      driver: 'ODBC Driver 17 for SQL Server',
      database: 'master', // Base de datos por defecto
      // connectionString: connectionString, // Connection string explícita
    );

    stdout.writeln('Creando cliente...');
    final client = SqlDbClient(config);
    
    try {
      stdout.writeln('Enviando query SELECT @@VERSION...');
      final response = await client.send(
        DbRequest.query(
          'SELECT @@VERSION AS version',
          errorMessage: 'Error al obtener versión',
        ),
      );

      stdout.writeln('');
      stdout.writeln('Response success: ${response.success}');
      stdout.writeln('Response rows count: ${response.rows.length}');
      if (response.error != null) {
        stderr.writeln('Response error: ${response.error}');
      }
      
      if (response.success && response.rows.isNotEmpty) {
        stdout.writeln('');
        stdout.writeln('✅ SQL Server Version:');
        stdout.writeln(response.rows.first['version']);
      }
      
      expect(response.success, isTrue, reason: response.error ?? 'Sin error');
      expect(response.rows, isNotEmpty);
    } finally {
      stdout.writeln('');
      stdout.writeln('Cerrando conexión...');
      await client.close();
      stdout.writeln('✓ Conexión cerrada');
    }
  });
}
