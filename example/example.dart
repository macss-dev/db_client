import 'repositories/example_repository.dart';

void main() async {
  try {
    // Example 1: Get SQL Server version
    print('Getting SQL Server version...');
    final version = await ExampleRepository.getVersion();
    print('SQL Server version: $version\n');

    // Example 2: Get database name
    print('Getting current database...');
    final dbName = await ExampleRepository.getDatabaseName();
    print('Connected to database: $dbName\n');

    // Example 3: Get all tables
    print('Getting tables from database...');
    final tables = await ExampleRepository.getTables();
    print('Found ${tables.length} tables:');
    for (final table in tables.take(5)) {
      print('  - ${table['schema']}.${table['name']} (${table['type']})');
    }
    if (tables.length > 5) {
      print('  ... and ${tables.length - 5} more');
    }

    // Example 4: Search table by name
    print('\nSearching for a specific table...');
    final sptValues = await ExampleRepository.getTableByName('spt_table');
    if (sptValues != null) {
      print('Found: ${sptValues['schema']}.${sptValues['name']}');
    } else {
      print('Table not found');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await ExampleRepository.close();
    print('\nConnection closed.');
  }
}