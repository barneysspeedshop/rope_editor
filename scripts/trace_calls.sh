#!/bin/bash
FILE="$1"
FRAME="$2"
MAX_DEPTH="${3:-30}"

trace_frame() {
  local current="$1"
  local depth="$2"
  
  if [ $depth -gt $MAX_DEPTH ]; then
    echo "  [Max depth $MAX_DEPTH reached]"
    return
  fi
  
  local info=$(jq -r ".\"cpu-profiler\".stackFrames.\"$current\" | {name, url: (.resolvedUrl | split(\"/\")[-1] // \"native\"), line: .sourceLine, parent}" "$FILE")
  local name=$(echo "$info" | jq -r '.name')
  local url=$(echo "$info" | jq -r '.url')  
  local line=$(echo "$info" | jq -r '.line')
  local parent=$(echo "$info" | jq -r '.parent')
  
  printf "%${depth}s%s - %s:%s\n" "" "$name" "$url" "$line"
  
  if [ "$parent" != "null" ] && [ -n "$parent" ]; then
    trace_frame "$parent" $((depth + 2))
  fi
}

# Commands: trace (default), hottest, api-calls, find
case "$FRAME" in
  --hottest)
    COUNT="${3:-20}"
    echo "=== Top $COUNT Hottest Functions ==="
    jq -r --argjson n "$COUNT" '.["cpu-profiler"].traceEvents | group_by(.sf) | map({sf: .[0].sf, count: length}) | sort_by(.count) | reverse | .[:$n] | .[] | "\(.count)\t\(.sf)"' "$FILE"
    ;;
    
  --api-calls)
    echo "=== Rust API Calls (grouped by frequency) ==="
    jq -r '.["cpu-profiler"].stackFrames | to_entries | map(select(.value.name | startswith("RustLibApiImpl.crateApi"))) | group_by(.value.name) | map({name: .[0].value.name, count: length}) | sort_by(.count) | reverse | .[] | "\(.count)\t\(.name)"' "$FILE"
    ;;
    
  --ffi-overhead)
    echo "=== FFI Overhead Analysis ==="
    echo ""
    echo "Stack frames in FFI boundary code:"
    jq -r '.["cpu-profiler"].stackFrames | to_entries | map(select(.value.resolvedUrl != null and (.value.resolvedUrl | test("multi_package|frb_generated|ffi_")))) | group_by(.value.name) | map({name: .[0].value.name, count: length}) | sort_by(.count) | reverse | .[] | "\(.count)\t\(.name)"' "$FILE"
    ;;
    
  --project)
    FILTER="${3:-rope_editor|rope_notes|code_forge}"
    echo "=== Project-Specific Hot Functions (filter: $FILTER) ==="
    jq -r --arg filter "$FILTER" '.["cpu-profiler"].stackFrames | to_entries | map(select(.value.resolvedUrl != null and (.value.resolvedUrl | test($filter)))) | map({id: .key, name: .value.name, file: (.value.resolvedUrl | split("/")[-1]), line: .value.sourceLine}) | unique_by(.name) | sort_by(.name) | .[] | "\(.name) - \(.file):\(.line)"' "$FILE"
    ;;

  --callers)
    # Find all callers of a function name
    FUNC_NAME="$3"
    echo "=== Callers of $FUNC_NAME ==="
    # Find frames that have this function as name, then look at their callers by checking who has this frame as parent
    FUNC_IDS=$(jq -r --arg name "$FUNC_NAME" '.["cpu-profiler"].stackFrames | to_entries | map(select(.value.name | test($name))) | .[].key' "$FILE")
    for fid in $FUNC_IDS; do
      echo "Frame: $fid"
      # Find frames that have this as parent
      jq -r --arg fid "$fid" '.["cpu-profiler"].stackFrames | to_entries | map(select(.value.parent == $fid)) | .[] | "  <- \(.value.name) (\(.key))"' "$FILE"
    done
    ;;

  --summary)
    echo "=== CPU Profile Summary ==="
    TOTAL=$(jq '.["cpu-profiler"].traceEvents | length' "$FILE")
    echo "Total samples: $TOTAL"
    echo ""
    echo "Top 10 functions by sample count:"
    jq -r '.["cpu-profiler"].traceEvents | group_by(.sf) | map({sf: .[0].sf, count: length}) | sort_by(.count) | reverse | .[0:10] | .[] | "  \(.count) samples (\(.count * 100 / '"$TOTAL"' | floor)%)"' "$FILE"
    echo ""
    echo "Run with --hottest to see frame IDs, then trace with: $0 <file> <frame_id>"
    ;;
    
  --help|-h)
    cat << 'HELP'
Usage: trace_calls.sh <trace_file.json> <command|frame_id> [options]

Commands:
  <frame_id>         Trace call stack from a frame ID (default)
  --hottest [N]      Show top N hottest functions (default: 20)
  --api-calls        Show Rust API calls grouped by frequency  
  --ffi-overhead     Analyze FFI boundary overhead
  --project [filter] Show project-specific functions (default: rope_editor|rope_notes|code_forge)
  --callers <func>   Find all callers of a function
  --summary          Show profile summary
  --help             Show this help

Options:
  For frame tracing: third arg is max depth (default: 30)

Examples:
  ./trace_calls.sh trace.json --hottest
  ./trace_calls.sh trace.json --api-calls
  ./trace_calls.sh trace.json "isolates/123-456"
  ./trace_calls.sh trace.json "isolates/123-456" 50
  ./trace_calls.sh trace.json --callers "_syncToConnection"
HELP
    ;;
    
  *)
    trace_frame "$FRAME" 0
    ;;
esac
