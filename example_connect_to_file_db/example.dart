import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:dotenv/dotenv.dart';

void main(List<String> args) async {
  await run(args);
}

Future<void> run(List<String> args) async {
  // loading variable from env
  final env = DotEnv()..load(['.env']);

  // ODBC driver name
  final driverName = env['DRIVER_NAME']!;
  final pathToFile = env['PATH_TO_FILE']!;

  // Verify file exists
  final file = File(pathToFile);
  if (!file.existsSync()) {
    print('Error: File not found at $pathToFile');
    return;
  }

  final connStr = 'DRIVER={$driverName};DBQ=$pathToFile;';
  final odbc = Odbc();

  try {
    await odbc.connectWithConnectionString(connStr);
    await _getAndPrintSheetsWithData(odbc);
  } catch (ex) {
    print('Error: $ex');
  } finally {
    await odbc.disconnect();
  }
}

// Handles retrieving and printing sheets and rows
Future<void> _getAndPrintSheetsWithData(Odbc odbc) async {
  print('Retrieving sheets...');
  final sheets = await odbc.getTables();

  if (sheets.isEmpty) {
    print('No sheets found.');
    return;
  }

  print('Sheets found:');
  for (final sheet in sheets) {
    _printPrettyJson(sheet);
  }

  // Extract sheet names
  final sheetNames =
      sheets.map((sheet) => sheet['TABLE_NAME'] as String).toList();

  for (final sheet in sheetNames) {
    print('\n\nSheet $sheet:');
    await _getAndPrintSheetData(odbc, sheet);
  }
}

// Fetch and print rows from a sheet
Future<void> _getAndPrintSheetData(Odbc odbc, String sheet) async {
  final rows = await odbc.execute('SELECT * FROM [$sheet]');

  if (rows.isEmpty) {
    print('No data in sheet: $sheet');
    return;
  }

  for (final row in rows) {
    _printPrettyJson(row);
  }
}

// Pretty print JSON data
void _printPrettyJson(Map<String, dynamic> jsonData) {
  const encoder = JsonEncoder.withIndent('  ');
  final prettyPrint = encoder.convert(jsonData);
  print(prettyPrint);
}
