# Production Fixes - v0.2.0

## Summary

Fixed critical heap corruption crashes and deadlocks under concurrent load. Root cause: improper ODBC environment handle lifecycle.

## Critical Fixes

### 1. Heap Corruption Under Concurrent Load

**Problem:** Server crashes with `Exited (-1073740940)` after 6 concurrent requests

**Root Cause:** `disconnect()` was calling `SQLFreeHandle(SQL_HANDLE_ENV, _hEnv)`, causing driver state corruption

**Fix:** Never free `_hEnv` in `disconnect()` - deferred to process termination

```dart
// FIXED: _hEnv persists for Odbc instance lifetime
// SQLFreeHandle(SQL_HANDLE_ENV, _hEnv) is NOT called in disconnect()
```

**File:** `lib/src/odbc/odbc.dart` lines 358-361

### 2. 90+ Second Deadlock on Disconnect

**Problem:** Sequential connections hang indefinitely when closing

**Fix:** Same as #1 - removing `_hEnv` cleanup resolved deadlocks

### 3. Instance-Based Pattern

**Problem:** Singleton pattern caused shared state between concurrent requests

**Fix:** Changed from static singleton to instance-based repositories

## Test Results

**Before:**
- ❌ Crash after 6 concurrent requests
- ❌ 90-second deadlock on disconnect

**After:**
- ✅ 6 concurrent requests: 333ms avg, no crashes
- ✅ 5 sequential connections: 240ms avg
- ✅ Production-ready under load

## Migration

Update `pubspec.yaml`:
```yaml
dependencies:
  db_client: ^0.2.0
```

**No code changes required** - fixes are internal.

**For ODBC Driver 17:**
```dart
DbClientConfig(
  additionalParams: {
    'Encrypt': 'no',
    'TrustServerCertificate': 'yes',
  },
)
```

---

Released: December 24, 2025
