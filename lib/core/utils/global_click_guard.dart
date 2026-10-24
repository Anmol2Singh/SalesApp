// lib/core/utils/global_click_guard.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// App-wide click blocker and debounce mechanism.
/// Prevents rapid duplicate clicks, repeated button taps,
/// and multiple concurrent asynchronous actions across the entire application.
class GlobalClickGuard {
  GlobalClickGuard._();

  static final ValueNotifier<bool> isBusyNotifier = ValueNotifier<bool>(false);
  static int _lastClickTimestamp = 0;
  static const int defaultCooldownMs = 500;

  /// Returns true if a click is allowed (at least [cooldownMs] has passed since last click),
  /// or false if this is a rapid multi-click that should be discarded.
  static bool canClick({int cooldownMs = defaultCooldownMs}) {
    if (isBusyNotifier.value) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastClickTimestamp < cooldownMs) {
      return false;
    }
    _lastClickTimestamp = now;
    return true;
  }

  /// Manually activate or deactivate the app-wide touch blocker
  static void setBusy(bool busy) {
    if (isBusyNotifier.value != busy) {
      isBusyNotifier.value = busy;
    }
  }

  /// Executes an async task while actively absorbing all pointer events across the app.
  /// Prevents double-clicking buttons, duplicate API submissions, or multiple screen pushes.
  static Future<T?> run<T>({
    required Future<T> Function() task,
    int cooldownMs = defaultCooldownMs,
  }) async {
    if (!canClick(cooldownMs: cooldownMs)) return null;

    setBusy(true);
    try {
      return await task();
    } finally {
      // Small cooldown buffer before re-enabling touches
      await Future.delayed(Duration(milliseconds: cooldownMs));
      setBusy(false);
    }
  }

  /// Wraps any synchronous [VoidCallback] to drop duplicate invocations within [cooldownMs].
  static VoidCallback? wrap(VoidCallback? callback, {int cooldownMs = defaultCooldownMs}) {
    if (callback == null) return null;
    return () {
      if (canClick(cooldownMs: cooldownMs)) {
        callback();
      }
    };
  }

  /// Wraps a single-argument callback [ValueChanged] to drop duplicate invocations within [cooldownMs].
  static ValueChanged<T>? wrapValue<T>(ValueChanged<T>? callback, {int cooldownMs = defaultCooldownMs}) {
    if (callback == null) return null;
    return (T value) {
      if (canClick(cooldownMs: cooldownMs)) {
        callback(value);
      }
    };
  }

  /// Wraps an asynchronous callback to ensure it cannot be triggered again while running.
  static VoidCallback? wrapAsync(Future<void> Function()? asyncCallback, {int cooldownMs = defaultCooldownMs}) {
    if (asyncCallback == null) return null;
    bool isRunning = false;
    return () async {
      if (isRunning || !canClick(cooldownMs: cooldownMs)) return;
      isRunning = true;
      setBusy(true);
      try {
        await asyncCallback();
      } finally {
        await Future.delayed(Duration(milliseconds: cooldownMs));
        isRunning = false;
        setBusy(false);
      }
    };
  }
}
