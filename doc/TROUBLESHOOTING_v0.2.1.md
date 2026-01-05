# Troubleshooting v0.2.1 - Exit Code -1073740940

## Problema Reportado

**Síntoma**: API REST termina con `Exited (-1073740940)` después de completar exitosamente un request.

**Exit Code**: `-1073740940` = `0xC0000374` = `STATUS_HEAP_CORRUPTION` (Windows)

## Contexto

- **Package**: db_client v0.2.1
- **Patrón**: Singleton con lazy initialization
- **Framework**: modular_api (Dart HTTP server)
- **Databases**: Oracle 11g + SQL Server 2019
- **Sistema**: Windows

## Log del Crash

```
[2025-12-27 09:53:40.969770] 💾 Log guardado: transfer_logs/transfer_5568452_20251227_095340.json
[2025-12-27 09:53:40.969770] ✅ Request completado - idPrestamo: 5568452

Exited (-1073740940).
```

## Diagnóstico

### ✅ Tests Unitarios: PASAN

Todos los tests con el mismo patrón singleton funcionan correctamente:

```bash
# Test simple con close()
dart test test/simple_test.dart
→ Exit code: 0 ✅

# Test de validación (50 queries)
dart test test/option_a_validation_test.dart
→ Exit code: 0 ✅

# Test de estrés del API (mismo patrón singleton)
dart test/db_stress_test.dart sequential 3 5562181
→ Exit code: 0 ✅
```

### ❌ API REST: CRASH al salir

El crash ocurre SOLO cuando el servidor API completo termina, no durante requests individuales.

**Diferencia clave**:
- **Tests**: Proceso simple que ejecuta queries y termina
- **API**: Framework web activo con event loop, HTTP server, múltiples isolates

## Análisis Técnico

### Hipótesis 1: Event Loop + ODBC Cleanup Timing Issue

El problema puede ser una race condition entre:
1. Dart VM intentando finalizar objetos
2. Framework `modular_api` haciendo cleanup
3. Event loop todavía procesando eventos
4. ODBC driver intentando cleanup interno

### Hipótesis 2: Múltiples Instancias del Repositorio

Aunque el `DbClient` es singleton, cada request crea nuevas instancias de:
```dart
late final oracle = OracleRepository();
late final mssql = MssqlRepository();
```

Estas instancias pueden tener:
- Futures pendientes
- Referencias colgantes
- Finalizers que se ejecutan en orden impredecible

### Hipótesis 3: Framework Lifecycle

El framework `modular_api` puede tener su propio lifecycle management que interfiere con ODBC cleanup:
- Middleware cleanup hooks
- Request context disposal
- HTTP server shutdown sequence

## Soluciones Potenciales

### Solución 1: Graceful Shutdown Hook

Agregar un handler explícito para señales de terminación:

```dart
// En bin/server.dart
import 'dart:io';

void main(List<String> args) async {
  final api = ModularApi(basePath: '/api/v1');
  
  // ... setup ...
  
  final server = await api.serve(port: port);
  
  // ✅ Graceful shutdown
  ProcessSignal.sigint.watch().listen((sig) async {
    print('Received SIGINT - shutting down gracefully...');
    await server.close(force: false);
    
    // Give ODBC time to stabilize before process exit
    await Future.delayed(Duration(milliseconds: 500));
    
    exit(0);
  });
}
```

### Solución 2: Singleton a Nivel de Caso de Uso

En lugar de crear nuevas instancias por request:

```dart
// Global singletons
final _oracleRepo = OracleRepository();
final _mssqlRepo = MssqlRepository();

class InvokeTransferencia {
  // Reutilizar instancias
  late final oracle = _oracleRepo;
  late final mssql = _mssqlRepo;
}
```

### Solución 3: Process.exitCode en lugar de process.exit()

Si el framework llama `exit()` forzosamente:

```dart
// En lugar de:
// exit(1);

// Usar:
exitCode = 1;
// Dejar que el event loop termine naturalmente
```

### Solución 4: Deshabilitar Finalizers de Dart (Experimental)

Agregar flag al ejecutar:

```bash
dart --no-enable-isolates bin/server.dart
```

O:

```bash
dart --no-concurrent-sweep bin/server.dart
```

## Verificación

### Test de Reproducción

1. **Ejecutar API y hacer 1 request**:
   ```bash
   # Terminal 1
   dart bin/server.dart
   
   # Terminal 2
   curl -X POST http://localhost:4031/api/v1/desembolso/invoke-transferencia \
     -H "Content-Type: application/json" \
     -d '{"idPrestamo": 5568452}'
   
   # Terminal 1 - Ctrl+C para terminar
   # ¿Exit code?
   ```

2. **Verificar si es consistente**:
   - ¿Siempre crashea?
   - ¿Solo después del primer request?
   - ¿Depende del número de requests?

3. **Comparar con test de estrés**:
   ```bash
   dart test/db_stress_test.dart sequential 5 5562181
   echo $LASTEXITCODE  # ¿Exit code 0?
   ```

## Estado Actual

### ✅ Implementación v0.2.1 Correcta

El código está implementado según especificación:
- ✅ `disconnect()` solo marca `_disconnected = true`
- ✅ No libera recursos ODBC
- ✅ No establece `_odbc = null` en `SqlDbClient.close()`
- ✅ Buffers retenidos en `Odbc` class

### ⚠️ Crash Específico del Framework

El problema parece ser específico del ciclo de vida del servidor HTTP, no del código db_client en sí.

## Próximos Pasos

1. **Implementar graceful shutdown** (Solución 1)
2. **Probar si el crash persiste** con shutdown controlado
3. **Si persiste**: Investigar lifecycle de `modular_api`
4. **Alternativa**: Agregar `--pause-isolates-on-exit` para depurar

## Referencias

- Issue original: [Link al log del crash]
- Documentación v0.2.1: `docs/SOLUTION_v0.2.1_OPTION_A.md`
- Implementación: `lib/src/odbc/odbc.dart` línea 376
