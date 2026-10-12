import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global provider for collapsing the desktop sidebar navigation to icons only.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
