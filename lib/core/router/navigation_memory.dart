// lib/core/router/navigation_memory.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/crm_date_filter.dart';

/// Saved UI state per screen/route
class ScreenUiState {
  final double scrollOffset;
  final String searchQuery;
  final String selectedStatus;
  final bool isDateGrouped;
  final CrmDateFilter? dateFilter;
  final int pageCount;
  final Map<String, dynamic> extra;

  const ScreenUiState({
    this.scrollOffset = 0.0,
    this.searchQuery = '',
    this.selectedStatus = 'All',
    this.isDateGrouped = true,
    this.dateFilter,
    this.pageCount = 1,
    this.extra = const {},
  });

  ScreenUiState copyWith({
    double? scrollOffset,
    String? searchQuery,
    String? selectedStatus,
    bool? isDateGrouped,
    CrmDateFilter? dateFilter,
    int? pageCount,
    Map<String, dynamic>? extra,
  }) {
    return ScreenUiState(
      scrollOffset: scrollOffset ?? this.scrollOffset,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isDateGrouped: isDateGrouped ?? this.isDateGrouped,
      dateFilter: dateFilter ?? this.dateFilter,
      pageCount: pageCount ?? this.pageCount,
      extra: extra ?? this.extra,
    );
  }
}

/// Centralized In-Memory Navigation and Per-Screen UI State Tracker.
/// Preserves exact scroll position, filters, search, and grouping across navigation stacks.
/// Fully clears ("forgets") upon visiting the Dashboard.
class NavigationMemory {
  static final Map<String, ScreenUiState> _states = {};
  static final List<String> _navigationStack = [];

  /// Get the remembered UI state for a route, or default if fresh
  static ScreenUiState getState(String routeKey, {ScreenUiState? defaultState}) {
    return _states[routeKey] ?? defaultState ?? const ScreenUiState();
  }

  /// Save the UI state for a route
  static void saveState(String routeKey, ScreenUiState state) {
    _states[routeKey] = state;
  }

  /// Save just the scroll offset for a route
  static void saveScroll(String routeKey, double offset) {
    final current = getState(routeKey);
    _states[routeKey] = current.copyWith(scrollOffset: offset);
  }

  /// Record navigation onto our logical stack tracker
  static void recordPush(String route) {
    _navigationStack.add(route);
  }

  /// Clears all saved list, scroll, filter states and navigation memory.
  /// Triggered genuinely upon navigating to the Dashboard (home).
  static void reset() {
    _states.clear();
    _navigationStack.clear();
    debugPrint('🧹 NavigationMemory: Cleared all saved scroll and filter states.');
  }

  static String? _lastVisitedDashboardRoute;

  /// Call on dashboard route entry. Only resets if entering fresh or from another screen.
  static void onDashboardEntered(String dashboardRoute) {
    if (_lastVisitedDashboardRoute != dashboardRoute) {
      reset();
      _lastVisitedDashboardRoute = dashboardRoute;
    }
  }

  /// Mark that user navigated to a non-dashboard screen
  static void onNavigateAwayFromDashboard() {
    _lastVisitedDashboardRoute = null;
  }

  /// Safe back navigation helper:
  /// Always returns to the previous screen natively when possible;
  /// otherwise falls back safely to [fallbackRoute] or splash.
  static void safeBack(BuildContext context, {String? fallbackRoute}) {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(fallbackRoute ?? '/');
    }
  }
}
