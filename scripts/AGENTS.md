# Agent Tools for Performance Analysis

## trace_calls.sh

A utility script for analyzing Dart DevTools CPU profiler traces. This script provides multiple commands for tracing call stacks, finding hot functions, and analyzing FFI overhead. If you find yourself needing more information, or manually performing additional steps that the script doesn't provide, consider modifying or adding to `trace_calls.sh` as needed, so that we have robust tooling that grows with the codebase.

### Quick Start

```bash
# Get a summary of the profile
./trace_calls.sh trace.json --summary

# Find hottest functions
./trace_calls.sh trace.json --hottest

# Trace a specific frame (from --hottest output)
./trace_calls.sh trace.json "isolates/123-456"
```

### Commands

| Command | Description |
|---------|-------------|
| `<frame_id>` | Trace call stack from a frame ID (default) |
| `--hottest [N]` | Show top N hottest functions (default: 20) |
| `--api-calls` | Show Rust API calls grouped by frequency |
| `--ffi-overhead` | Analyze FFI boundary overhead |
| `--project [filter]` | Show project-specific functions |
| `--callers <func>` | Find all callers of a function |
| `--summary` | Show profile summary with percentages |
| `--help` | Show help |

### Example Workflow

1. **Export CPU trace from Dart DevTools** (Performance tab → CPU Profiler → Export)

2. **Get overview:**
   ```bash
   ./trace_calls.sh dart_devtools.json --summary
   ```

3. **Find hottest functions:**
   ```bash
   ./trace_calls.sh dart_devtools.json --hottest 10
   ```

4. **Trace a hot function (with extended depth):**
   ```bash
   ./trace_calls.sh dart_devtools.json "isolates/123-456" 50
   ```

5. **Find what's calling a function:**
   ```bash
   ./trace_calls.sh dart_devtools.json --callers "_syncToConnection"
   ```

6. **Analyze FFI overhead:**
   ```bash
   ./trace_calls.sh dart_devtools.json --ffi-overhead
   ```

### Output Example

```
#ffiClosure10 - multi_package.dart:297
  MultiPackageCBinding.frb_pde_ffi_dispatcher_sync - multi_package.dart:278
    GeneralizedFrbRustBinding.pdeFfiDispatcherSync - _io.dart:58
      pdeCallFfi - pde.dart:6
        RustLibApiImpl.crateApiGetImeProjection.<anonymous closure> - frb_generated.dart:683
          BaseHandler.executeSync - handler.dart:21
            RustLibApiImpl.crateApiGetImeProjection - frb_generated.dart:673
              getImeProjection - api.dart:408
                Rope.getImeProjection - rope.dart:476
                  RopeEditorController._ensureImeProjection - controller.dart:682
                    RopeEditorController._syncToConnection - controller.dart:671
```

### Interpretation

- **Top of trace** = Where CPU time is spent (e.g., FFI boundary)
- **Bottom of trace** = Where the call originated (e.g., user-facing API)
- **Indentation** = Call depth
- **File:line** = Exact location in source code

### Performance Optimization Tips

1. **FFI Overhead**: If you see many `#ffiClosure` or `multi_package.dart` calls, you're crossing the Dart ↔ Rust boundary too often
   - Solution: Batch API calls, cache results, use lazy evaluation

2. **Repeated Calls**: If the same call stack appears thousands of times
   - Solution: Move computation out of hot loops, add caching

3. **Metrics Rebuild**: If `ensure_metrics` or `update_metrics` appears in hot paths
   - Solution: Defer metrics rebuild, use incremental updates
   - See project history in git for the Zed rope migration investigation.

4. **Deep Stacks**: Very deep call stacks in hot paths
   - Solution: Flatten call hierarchy, inline critical paths

### Limitations

- Traces up to 30 levels deep by default (configurable via third argument)
- Requires valid Dart DevTools CPU profiler JSON export
- Frame IDs are session-specific (change each run)

### Script Location

This script is located in the `scripts/` directory and can be used by both human developers and AI agents for performance analysis.

---

## Related Documentation

