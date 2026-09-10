// lib/features/admin/screens/workflow_config_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import 'product_catalog_screen.dart';

class WorkflowConfigScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const WorkflowConfigScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<WorkflowConfigScreen> createState() => _WorkflowConfigScreenState();
}

class _WorkflowConfigScreenState extends ConsumerState<WorkflowConfigScreen> {
  String? _selectedProductId;
  List<Map<String, dynamic>> _stepsList = [];
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('Workflow Configuration'),
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(
              child: Text(
                'No products available to configure.\nCreate products in the Catalog tab first.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
              ),
            );
          }

          if (_selectedProductId == null) {
            // Default to first product
            _selectedProductId = products.first.id;
            _loadWorkflowSteps(_selectedProductId!);
          }

          return Column(
            children: [
              // Product Selector Dropdown
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    const Text(
                      'Configure Product:',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedProductId,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: products.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(p.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedProductId = val;
                              _stepsList = [];
                            });
                            _loadWorkflowSteps(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Steps List Editor
              Expanded(
                child: _stepsList.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Workflow Stages (Drag to Reorder)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ReorderableListView(
                              onReorder: _reorderSteps,
                              children: [
                                for (int i = 0; i < _stepsList.length; i++)
                                  ListTile(
                                    key: ValueKey(_stepsList[i]['id'] ?? '$i'),
                                    leading: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      _stepsList[i]['name'] ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'ID: ${_stepsList[i]['id']}  •  Owner: ${_stepsList[i]['owner_role'] ?? 'sales'}  •  PDF: ${_stepsList[i]['pdf_generation'] == true ? 'Yes' : 'No'}',
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          onPressed: () => _showEditStepDialog(i),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                          onPressed: () => _deleteStep(i),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showAddStepDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Stage'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveWorkflowConfig,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _loadWorkflowSteps(String productId) async {
    try {
      final steps = await ref.read(workflowStepsProvider(productId).future);
      setState(() {
        _stepsList = List<Map<String, dynamic>>.from(
          steps.map((item) => Map<String, dynamic>.from(item)),
        );
      });
    } catch (e) {
      debugPrint("Error loading workflow steps: $e");
    }
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _stepsList.removeAt(oldIndex);
      _stepsList.insert(newIndex, item);
    });
  }

  void _showEditStepDialog(int index) {
    final nameController = TextEditingController(text: _stepsList[index]['name']);
    String selectedRole = _stepsList[index]['owner_role'] ?? 'sales';
    bool pdfGen = _stepsList[index]['pdf_generation'] == true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Stage Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Stage Display Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Owner Role'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'sales_head', child: Text('Sales Head')),
                    DropdownMenuItem(value: 'sales', child: Text('Sales')),
                    DropdownMenuItem(value: 'factory', child: Text('Factory')),
                    DropdownMenuItem(value: 'purchase', child: Text('Purchase')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Generate PDF for this stage?'),
                    Switch(
                      value: pdfGen,
                      onChanged: (val) {
                        setDialogState(() => pdfGen = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    setState(() {
                      _stepsList[index]['name'] = newName;
                      _stepsList[index]['owner_role'] = selectedRole;
                      _stepsList[index]['pdf_generation'] = pdfGen;
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _deleteStep(int index) {
    if (_stepsList.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workflow must contain at least 1 stage.')),
      );
      return;
    }
    setState(() {
      _stepsList.removeAt(index);
    });
  }

  void _showAddStepDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'sales';
    bool pdfGen = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Workflow Stage'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Stage ID (lowercase, e.g., quotation, boq)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name (e.g., Quotation)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Owner Role'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'sales_head', child: Text('Sales Head')),
                    DropdownMenuItem(value: 'sales', child: Text('Sales')),
                    DropdownMenuItem(value: 'factory', child: Text('Factory')),
                    DropdownMenuItem(value: 'purchase', child: Text('Purchase')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Generate PDF for this stage?'),
                    Switch(
                      value: pdfGen,
                      onChanged: (val) {
                        setDialogState(() => pdfGen = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final id = idController.text.trim().toLowerCase();
                  final name = nameController.text.trim();

                  if (id.isEmpty || name.isEmpty) return;

                  // Check if ID already exists
                  if (_stepsList.any((s) => s['id'] == id)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stage ID must be unique.')),
                    );
                    return;
                  }

                  setState(() {
                    _stepsList.add({
                      'id': id,
                      'name': name,
                      'owner_role': selectedRole,
                      'pdf_generation': pdfGen,
                    });
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _saveWorkflowConfig() async {
    if (_selectedProductId == null) return;

    setState(() => _isSaving = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      await supabase.from('workflow_definitions').upsert({
        'product_id': _selectedProductId,
        'steps': _stepsList,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'product_id');

      ref.invalidate(workflowStepsProvider(_selectedProductId!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workflow steps updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save configuration: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
