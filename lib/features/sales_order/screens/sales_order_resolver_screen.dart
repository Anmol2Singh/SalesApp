// lib/features/sales_order/screens/sales_order_resolver_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'sales_order_form_screen.dart';

/// Resolves either a sales_orders record ID (UUID) or a pipeline ID (UUID)
/// and displays the standard SalesOrderFormScreen without throwing 404.
class SalesOrderResolverScreen extends ConsumerStatefulWidget {
  final String orderOrPipelineId;

  const SalesOrderResolverScreen({super.key, required this.orderOrPipelineId});

  @override
  ConsumerState<SalesOrderResolverScreen> createState() =>
      _SalesOrderResolverScreenState();
}

class _SalesOrderResolverScreenState
    extends ConsumerState<SalesOrderResolverScreen> {
  String? _resolvedPipelineId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resolvePipelineId();
  }

  Future<void> _resolvePipelineId() async {
    final rawId = widget.orderOrPipelineId.trim();
    if (rawId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid ID provided';
        });
      }
      return;
    }

    try {
      final supabase = ref.read(supabaseClientProvider);
      // 1. Check if rawId is a sales_orders table id
      final soRes = await supabase
          .from('sales_orders')
          .select('pipeline_id')
          .eq('id', rawId)
          .maybeSingle();

      if (soRes != null && soRes['pipeline_id'] != null) {
        if (mounted) {
          setState(() {
            _resolvedPipelineId = soRes['pipeline_id'].toString();
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Otherwise assume rawId is already a pipeline_id
      if (mounted) {
        setState(() {
          _resolvedPipelineId = rawId;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Fallback: use rawId directly as pipeline ID
      if (mounted) {
        setState(() {
          _resolvedPipelineId = rawId;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null || _resolvedPipelineId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sales Order')),
        body: Center(
          child: Text(_errorMessage ?? 'Unable to resolve Sales Order'),
        ),
      );
    }

    return SalesOrderFormScreen(pipelineId: _resolvedPipelineId!);
  }
}

