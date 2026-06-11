import 'package:flutter/foundation.dart';
import 'package:rope_editor/src/rope/anchor.dart';

/// A global version vector that tracks which operations have been observed.
/// Used for CRDT synchronization and version tracking.
@immutable
class GlobalVersion {
  /// Map of replica IDs to their observed Lamport timestamps.
  final Map<int, int> _observed;
  
  const GlobalVersion._(this._observed);
  
  /// Create an empty version vector.
  factory GlobalVersion.empty() => const GlobalVersion._({});
  
  /// Create a version vector with a single observed timestamp.
  factory GlobalVersion.single(LamportTimestamp timestamp) {
    return GlobalVersion._({timestamp.replicaId: timestamp.value});
  }
  
  /// Check if this version has observed a specific timestamp.
  bool observed(LamportTimestamp timestamp) {
    final observedValue = _observed[timestamp.replicaId];
    return observedValue != null && observedValue >= timestamp.value;
  }
  
  /// Check if this version has observed all timestamps in another version.
  bool observedAll(GlobalVersion other) {
    for (final entry in other._observed.entries) {
      final observedValue = _observed[entry.key];
      if (observedValue == null || observedValue < entry.value) {
        return false;
      }
    }
    return true;
  }
  
  /// Create a new version that includes an observed timestamp.
  GlobalVersion observe(LamportTimestamp timestamp) {
    final newObserved = Map<int, int>.from(_observed);
    final current = newObserved[timestamp.replicaId] ?? 0;
    if (timestamp.value > current) {
      newObserved[timestamp.replicaId] = timestamp.value;
    }
    return GlobalVersion._(newObserved);
  }
  
  /// Merge two version vectors.
  GlobalVersion merge(GlobalVersion other) {
    final merged = Map<int, int>.from(_observed);
    for (final entry in other._observed.entries) {
      final current = merged[entry.key] ?? 0;
      if (entry.value > current) {
        merged[entry.key] = entry.value;
      }
    }
    return GlobalVersion._(merged);
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalVersion && mapEquals(_observed, other._observed);
  
  @override
  int get hashCode => Object.hashAll(_observed.entries);
  
  @override
  String toString() {
    final entries = _observed.entries.map((e) => '${e.key}:${e.value}').join(', ');
    return 'Version($entries)';
  }
}

/// Tracks buffer history with version snapshots.
/// Enables reconstructing the buffer state at any historical version.
class VersionedHistory {
  final List<VersionedSnapshot> _snapshots = [];
  final int _maxSnapshots;
  
  /// The current version.
  GlobalVersion _version = GlobalVersion.empty();
  
  VersionedHistory({int maxSnapshots = 100}) : _maxSnapshots = maxSnapshots;
  
  GlobalVersion get version => _version;
  
  /// Record a new version with associated content.
  void recordVersion(LamportTimestamp timestamp, String content) {
    _version = _version.observe(timestamp);
    
    _snapshots.add(VersionedSnapshot(
      version: _version,
      timestamp: timestamp,
      content: content,
    ));
    
    // Prune old snapshots
    while (_snapshots.length > _maxSnapshots) {
      _snapshots.removeAt(0);
    }
  }
  
  /// Get the content at a specific version, if available.
  String? contentAtVersion(GlobalVersion targetVersion) {
    // Find the closest snapshot that matches the target version
    for (final snapshot in _snapshots.reversed) {
      if (targetVersion.observedAll(snapshot.version)) {
        return snapshot.content;
      }
    }
    return null;
  }
  
  /// Get the most recent snapshot.
  VersionedSnapshot? get latestSnapshot => 
      _snapshots.isEmpty ? null : _snapshots.last;
  
  /// Check if a specific version has been observed.
  bool hasVersion(LamportTimestamp timestamp) {
    return _version.observed(timestamp);
  }
  
  /// Clear all version history.
  void clear() {
    _snapshots.clear();
    _version = GlobalVersion.empty();
  }
}

/// A snapshot of buffer content at a specific version.
@immutable
class VersionedSnapshot {
  final GlobalVersion version;
  final LamportTimestamp timestamp;
  final String content;
  
  const VersionedSnapshot({
    required this.version,
    required this.timestamp,
    required this.content,
  });
  
  @override
  String toString() => 'Snapshot($timestamp, ${content.length} chars)';
}

/// A subscription to buffer changes at a specific position.
/// Used for tracking diagnostic positions, selections, etc.
class VersionedSubscription {
  final Anchor anchor;
  final GlobalVersion subscribeVersion;
  bool _isActive = true;
  
  VersionedSubscription({
    required this.anchor,
    required this.subscribeVersion,
  });
  
  bool get isActive => _isActive;
  
  void cancel() {
    _isActive = false;
  }
}
