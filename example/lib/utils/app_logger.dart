import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

/// Simple logging system that captures all Flutter warnings and errors,
/// categorizes them, and prints a clean summary in the CLI.
class AppLogger {
  AppLogger._();

  static final List<LogEntry> _entries = [];
  static final List<LogEntry> _errors = [];
  static final List<LogEntry> _warnings = [];

  static List<LogEntry> get entries => List.unmodifiable(_entries);
  static List<LogEntry> get errors => List.unmodifiable(_errors);
  static List<LogEntry> get warnings => List.unmodifiable(_warnings);

  /// Initialize the logger. Call this before runApp().
  /// Wraps the app in error handling zones.
  static void runWithLogger(Widget app) {
    // Capture Flutter framework errors (RenderFlex overflow, assertion errors, etc.)
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _captureFlutterError(details);
      // Still call original handler so errors show in debug console
      originalOnError?.call(details);
    };

    // Capture uncaught async errors
    runZonedGuarded(
      () {
        WidgetsFlutterBinding.ensureInitialized();
        runApp(app);
      },
      (error, stackTrace) {
        _captureZoneError(error, stackTrace);
      },
    );

    // Print summary on shutdown (won't fire in web, but useful for desktop/mobile)
    developer.log(
      '🔧 AppLogger initialized — errors/warnings will be printed to CLI',
      name: 'AppLogger',
    );
  }

  static void _captureFlutterError(FlutterErrorDetails details) {
    final category = _categorizeFlutterError(details);
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: category.level,
      category: category.name,
      message: details.exceptionAsString(),
      details: details.toString(),
      stackTrace: details.stack,
    );

    _entries.add(entry);
    if (entry.level == LogLevel.error) {
      _errors.add(entry);
    } else {
      _warnings.add(entry);
    }

    _printEntry(entry);
  }

  static void _captureZoneError(Object error, StackTrace stackTrace) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.error,
      category: 'UNCAUGHT',
      message: error.toString(),
      stackTrace: stackTrace,
    );

    _entries.add(entry);
    _errors.add(entry);
    _printEntry(entry);
  }

  static _ErrorCategory _categorizeFlutterError(FlutterErrorDetails details) {
    final message = details.exceptionAsString().toLowerCase();
    final library = details.library ?? '';

    // RenderFlex / layout errors
    if (message.contains('renderflex') ||
        message.contains('overflowed') ||
        message.contains('renderbox was not laid out') ||
        message.contains('has no size') ||
        library.contains('rendering')) {
      return _ErrorCategory('LAYOUT', LogLevel.error);
    }

    // Assertion errors (usually from framework)
    if (details.exception is AssertionError) {
      return _ErrorCategory('ASSERTION', LogLevel.error);
    }

    // State errors
    if (details.exception is StateError ||
        message.contains('setstate') ||
        message.contains('disposed')) {
      return _ErrorCategory('STATE', LogLevel.error);
    }

    // Null / type errors
    if (details.exception is TypeError || details.exception is NoSuchMethodError) {
      return _ErrorCategory('TYPE', LogLevel.error);
    }

    // Paint / rendering warnings
    if (library.contains('painting') || library.contains('image')) {
      return _ErrorCategory('PAINT', LogLevel.warning);
    }

    // Gesture errors
    if (library.contains('gesture')) {
      return _ErrorCategory('GESTURE', LogLevel.warning);
    }

    return _ErrorCategory('FRAMEWORK', LogLevel.error);
  }

  static void _printEntry(LogEntry entry) {
    final time = _formatTime(entry.timestamp);
    final icon = entry.level == LogLevel.error ? '❌' : '⚠️';
    final label = entry.level == LogLevel.error ? 'ERROR' : 'WARN';

    // Use debugPrint for reliable CLI output (won't be truncated)
    debugPrint('');
    debugPrint('$icon [$time] $label [${entry.category}]');
    debugPrint('  ${entry.message}');

    // Print first few lines of details for context
    if (entry.details != null) {
      final lines = entry.details!.split('\n');
      final preview = lines.take(5).map((l) => '  $l').join('\n');
      debugPrint(preview);
      if (lines.length > 5) {
        debugPrint('  ... (${lines.length - 5} more lines)');
      }
    }
  }

  /// Print a summary of all collected errors and warnings.
  static void printSummary() {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('  AppLogger Summary');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('  Total entries: ${_entries.length}');
    debugPrint('  Errors: ${_errors.length}');
    debugPrint('  Warnings: ${_warnings.length}');

    if (_entries.isEmpty) {
      debugPrint('  ✅ No issues detected!');
      debugPrint('═══════════════════════════════════════════');
      return;
    }

    // Group by category
    final grouped = <String, List<LogEntry>>{};
    for (final entry in _entries) {
      grouped.putIfAbsent(entry.category, () => []).add(entry);
    }

    debugPrint('───────────────────────────────────────────');
    debugPrint('  By Category:');
    for (final category in grouped.keys.toList()..sort()) {
      final items = grouped[category]!;
      final errorCount = items.where((e) => e.level == LogLevel.error).length;
      final warnCount = items.where((e) => e.level == LogLevel.warning).length;
      debugPrint('    $category: $errorCount errors, $warnCount warnings');
    }

    debugPrint('───────────────────────────────────────────');
    debugPrint('  Unique Messages:');
    final uniqueMessages = <String>{};
    for (final entry in _entries) {
      final short = entry.message.length > 80
          ? '${entry.message.substring(0, 80)}...'
          : entry.message;
      if (uniqueMessages.add(short)) {
        final icon = entry.level == LogLevel.error ? '❌' : '⚠️';
        final count = _entries.where((e) => e.message == entry.message).length;
        final suffix = count > 1 ? ' (x$count)' : '';
        debugPrint('    $icon $short$suffix');
      }
    }
    debugPrint('═══════════════════════════════════════════');
  }

  /// Clear all collected entries.
  static void clear() {
    _entries.clear();
    _errors.clear();
    _warnings.clear();
    debugPrint('🧹 AppLogger cleared');
  }

  static String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }
}

enum LogLevel { warning, error }

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.details,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;
  final String? details;
  final StackTrace? stackTrace;
}

class _ErrorCategory {
  const _ErrorCategory(this.name, this.level);
  final String name;
  final LogLevel level;
}
