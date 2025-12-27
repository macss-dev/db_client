# Intermittent Crash Issue: Access Violation (-1073740791)

**Status:** 🔴 Active Investigation  
**Severity:** Critical  
**Affected Versions:** db_client v0.2.0+  
**Platform:** Windows  
**Error Code:** `Exited (-1073740791)` (STATUS_STACK_BUFFER_OVERRUN)

---

## Problem Description

The `db_client` package experiences intermittent crashes with exit code `-1073740791` when used in production. The crash is non-deterministic - the same code sometimes works correctly and sometimes crashes.

### Error Details

```
Exited (-1073740791)
```

This Windows error code corresponds to `STATUS_STACK_BUFFER_OVERRUN` (0xC0000409), indicating:
- Stack buffer overflow
- Memory corruption during function return
- Potential race condition in native code

### Observed Pattern

The crash occurs in a production REST API endpoint (`/api/v1/desembolso/invoke-transferencia`) that:

1. ✅ Executes Oracle query (e.g., `getProductoInfoByIdPrestamo`)
2. ✅ Executes SQL Server query (e.g., `getIdSolicitud`)
3. ✅ Executes additional Oracle query (e.g., `getSaldoCuentaDesembolso`)
4. ✅ Executes additional SQL Server query (e.g., `getDatosDesembolso`)
5. ⚠️ External HTTP service returns error (e.g., Ligo API HTTP 400)
6. ❌ **CRASH** - Process terminates with `-1073740791`

**Key observations:**
- All database queries complete successfully before the crash
- Crash appears to occur during cleanup/exception handling
- No error is thrown in Dart code - process simply exits
- Happens intermittently, not on every request

### Example Production Log

```log
[2025-12-24 11:11:05.519] Oracle OK - idPrestamo: 5562963, monto: S/ 1000.00
[2025-12-24 11:11:05.537] Preparado para LIGO - idPrestamo: 5562963
Token de Ligo no válido o expirado: Sin token
[DEBUG] accountInquiry payload: {...}
HTTP Error Response: Status: 400
Error en llamada con token: HttpClientException: ...

Exited (-1073740791).  ← CRASH HERE
```

---

## Environment

### Database Drivers
- **Oracle:** Oracle Instant Client 21.17
- **SQL Server:** ODBC Driver 17 for SQL Server
- **Platform:** Windows Server

### Architecture
- **Pattern:** Singleton repository pattern (one connection per database)
- **Concurrency:** `GlobalOdbcLock` mutex protects connection creation
- **Resource Management:** Connections are never explicitly closed (singleton lifetime)

### Previous Related Issues

**v0.2.0 fixes:**
- ✅ Fixed `_hEnv` handle leak by NOT freeing it in `disconnect()`
- ✅ Fixed heap corruption (error `-1073740940`)
- ✅ Added double-disconnect protection

The current crash (`-1073740791`) is a **different issue** that persists after v0.2.0 fixes.

---

## Technical Analysis

### Hypotheses

#### 🔴 Primary Hypothesis: Finalizer Race Condition

**Theory:**
1. Request executes queries successfully
2. External exception thrown (e.g., HTTP error)
3. Dart stack unwinds, ODBC resources become unreferenced
4. Garbage collector triggers FFI finalizers
5. **Finalizer attempts to free native memory while ODBC driver still references it**
6. Access violation in native code

**Evidence:**
- Crash occurs AFTER exception, not during query execution
- Error code indicates stack buffer overrun (typical of use-after-free)
- v0.2.0 already fixed similar issue with `_hEnv` lifetime management

**Critical Code Areas:**

```dart
// In execute() - odbc.dart line ~348
final pHStmt = calloc.allocate<SQLHSTMT>(sizeOf<SQLHSTMT>());
// ... SQLAllocHandle ...
// ... SQLExecute ...

// Free memory
calloc.free(pHStmt);  // ⚠️ What if ODBC driver has delayed reference?
```

```dart
// In _getResult() - odbc.dart lines ~470-580
while (!done) {
  final buf = calloc.allocate<Uint16>(bufBytes);
  _sql.SQLGetData(hStmt, i, SQL_WCHAR, buf.cast(), bufBytes, ...);
  
  collected.addAll(buf.asTypedList(unitsReturned));  // ⚠️ If unitsReturned > allocated?
  
  calloc.free(buf);  // ⚠️ Immediate free - what if driver is async?
}
```

#### 🟡 Secondary Hypothesis: Buffer Size Calculation Error

**Theory:**
- Complex logic to calculate `unitsReturned` in incremental reads (WCHAR/BINARY)
- Edge case where calculation exceeds allocated buffer size
- `asTypedList(unitsReturned)` attempts to read beyond buffer bounds
- Stack corruption when native code accesses invalid memory

**Critical Code:**

```dart
// odbc.dart ~line 540
int unitsReturned;
if (returnedBytes == SQL_NO_TOTAL) {
  unitsReturned = unitBuf - 1;  // Assumption: buffer is full
} else if (returnedBytes > 0) {
  if (status == SQL_SUCCESS_WITH_INFO || returnedBytes > bufBytes) {
    unitsReturned = unitBuf - 1;  // ⚠️ Another assumption
  } else {
    unitsReturned = returnedBytes ~/ sizeOf<Uint16>();
  }
}

collected.addAll(buf.asTypedList(unitsReturned));  // ⚠️ NO bounds checking
```

#### 🟡 Tertiary Hypothesis: Driver Thread-Safety Issue

**Theory:**
- ODBC drivers have internal shared state that is not fully thread-safe
- `GlobalOdbcLock` only protects connection creation, not query execution
- Concurrent queries on different connections corrupt shared driver state
- Corruption manifests during cleanup as access violation

**Evidence:**
- Need for `GlobalOdbcLock` indicates driver issues
- Production uses singleton pattern but still crashes (queries are sequential)

---

## Reproduction Strategy

### Test Suite Overview

Three test files target different crash scenarios:

#### 1. `realistic_workflow_test.dart`
**Purpose:** Replicate exact production query pattern

```dart
- Sequential Oracle + SQL Server queries
- Metadata operations
- Rapid sequential queries (20 iterations)
- Exception handling with GC
```

**Focus:** Reproduce the production workflow as closely as possible.

#### 2. `cleanup_test.dart`
**Purpose:** Test resource cleanup under exception conditions

```dart
- Query + Exception + Forced GC (15 iterations)
- Create/destroy without explicit close() (20 iterations)
- Exception at different query stages
- Nested exception handling
```

**Focus:** Trigger GC-related finalizer race conditions.

#### 3. Test Execution Recommendations

**Run tests sequentially, increasing iterations until crash reproduces:**

```bash
# Phase 1: Realistic workflow (10 iterations)
dart test test/realistic_workflow_test.dart

# Phase 2: Cleanup tests (15-20 iterations)
dart test test/cleanup_test.dart

# Phase 3: Extended stress (increase iterations in code)
# Modify iteration counts: 10 → 50 → 100 → 500
```

**ODBC Tracing:**
- All tests enable ODBC tracing automatically
- Logs written to `C:\temp\odbc_trace_*.log`
- Review logs immediately after crash to capture native stack trace

---

## Current Workarounds

### In Production (mdm_api)

1. **Singleton Pattern**
   ```dart
   // One connection per database - never close
   static DbClient? _client;
   ```

2. **GlobalOdbcLock Mutex**
   ```dart
   // Serialize connection creation
   await GlobalOdbcLock.acquire();
   try {
     _client = SqlDbClient(config);
   } finally {
     GlobalOdbcLock.release();
   }
   ```

3. **No Explicit Close**
   ```dart
   // Let OS clean up on process exit
   // Removed all client.close() calls
   ```

**Result:** Reduced crash frequency but did NOT eliminate the issue.

---

## Investigation Status

### Completed
- ✅ Analyzed production logs and identified crash pattern
- ✅ Created realistic test suite replicating production workflow
- ✅ Enabled ODBC tracing for detailed diagnostics
- ✅ Documented code areas most likely to cause issue

### In Progress
- 🔄 Running test suite to reproduce crash consistently
- 🔄 Analyzing ODBC trace logs for driver-level issues

### Next Steps
1. Reproduce crash consistently (target: 100% repro rate)
2. Capture full native stack trace using WinDbg or similar
3. Identify exact native function causing access violation
4. Implement fix:
   - Option A: Add reference counting for FFI buffers
   - Option B: Extend resource lifetime (like v0.2.0 `_hEnv` fix)
   - Option C: Add bounds checking in buffer reads
   - Option D: Extend `GlobalOdbcLock` to cover all ODBC operations

---

## Additional Resources

### Related Files
- `lib/src/odbc/odbc.dart` - Core ODBC implementation (lines 470-580 critical)
- `lib/src/odbc/helper.dart` - FFI conversion utilities
- `lib/src/sql_db_client.dart` - High-level client wrapper
- `docs/PRODUCTION_FIXES_v0.2.0.md` - Previous fixes for similar issues

### External References
- [Windows Error Codes](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/596a1078-e883-4972-9bbc-49e60bebca55)
- [ODBC API Reference](https://learn.microsoft.com/en-us/sql/odbc/reference/syntax/odbc-api-reference)
- [FFI Best Practices](https://dart.dev/guides/libraries/c-interop)

---

## Contact

For questions or updates on this issue, please:
- Review test results in `test/` directory
- Check ODBC trace logs in `C:\temp\odbc_trace_*.log`
- Monitor production logs for crash patterns

**Last Updated:** 2025-12-26  
**Tracking:** This is a critical production issue requiring immediate investigation.
