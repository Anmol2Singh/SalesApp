// lib/features/admin/screens/noc_certificate_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../quotation_generator/data/qg_noc_repository.dart';
import '../../quotation_generator/models/qg_noc_profile.dart';

class NocCertificateSettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const NocCertificateSettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<NocCertificateSettingsScreen> createState() => _NocCertificateSettingsScreenState();
}

class _NocCertificateSettingsScreenState extends State<NocCertificateSettingsScreen> {
  late Future<List<QgNocProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  void _loadProfiles() {
    setState(() {
      _profilesFuture = QgNocRepository.fetchProfiles();
    });
  }

  Future<void> _showAddProfileDialog() async {
    final nameController = TextEditingController();
    final point1Controller = TextEditingController(text: '1. The installation of the system is permitted at the above location.');
    final point2Controller = TextEditingController(text: '2. The system complies as per standard safety norms and guidelines.');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product NOC Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Product Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Solar Water Heater, Water Purifier',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const Text('Initial Confirmation Point 1', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: point1Controller,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Initial Confirmation Point 2', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: point2Controller,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF174895),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final prodName = nameController.text.trim();
                final points = [
                  point1Controller.text.trim(),
                  point2Controller.text.trim(),
                ].where((p) => p.isNotEmpty).toList();

                try {
                  await QgNocRepository.saveProfileConfirmations(
                    'new_${DateTime.now().millisecondsSinceEpoch}',
                    points,
                    productName: prodName,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(backgroundColor: AppColors.error, content: Text('Error adding profile: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Create Profile'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppColors.success, content: Text('Product NOC profile created successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: () async => _loadProfiles(),
      child: FutureBuilder<List<QgNocProfile>>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profiles = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Top Action / Hub Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF174895).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF174895).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 36, color: Color(0xFF174895)),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Installation & Commissioning NOC Hub',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF174895),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage, issue, and print contractor installation certificates.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/qg/noc'),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open Hub'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF174895),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Preset NOC Profiles Section Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preset NOC Profiles',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'These profiles define default equipment labels, subjects, checklists, and scope phrasing when generating NOCs.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _showAddProfileDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Profile', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (profiles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Text('No NOC Profiles configured yet.', style: TextStyle(color: Colors.grey)),
                )
              else
                ...profiles.map((p) {
                  return _NocProfileCard(
                    key: ValueKey('noc_profile_${p.id}_${p.productName}'),
                    profile: p,
                    onSaved: _loadProfiles,
                  );
                }),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('NOC Certificates'),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: content,
    );
  }
}

class _NocProfileCard extends StatefulWidget {
  final QgNocProfile profile;
  final VoidCallback onSaved;

  const _NocProfileCard({
    super.key,
    required this.profile,
    required this.onSaved,
  });

  @override
  State<_NocProfileCard> createState() => _NocProfileCardState();
}

class _NocProfileCardState extends State<_NocProfileCard> {
  bool _isExpanded = false;
  bool _isSaving = false;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.profile.defaultConfirmations
        .map((c) => TextEditingController(text: c))
        .toList();
  }

  @override
  void didUpdateWidget(_NocProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.defaultConfirmations.length != widget.profile.defaultConfirmations.length) {
      for (final c in _controllers) {
        c.dispose();
      }
      _controllers = widget.profile.defaultConfirmations
          .map((c) => TextEditingController(text: c))
          .toList();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final points = _controllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      await QgNocRepository.saveProfileConfirmations(
        widget.profile.id,
        points,
        productName: widget.profile.productName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Saved ${points.length} confirmation points for ${widget.profile.profileName}'),
          ),
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to save profile confirmations: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.profile.profileName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF286B37).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.profile.productName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF286B37),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _isExpanded ? 'Collapse' : 'Manage Confirmations',
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Subject: ${widget.profile.defaultSubject}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Work Type: ${widget.profile.workType}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Confirmations: ${_controllers.length} points',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),

            if (_isExpanded) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'We confirm that: (Manage Points)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Point', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        final nextIndex = _controllers.length + 1;
                        _controllers.add(TextEditingController(text: '$nextIndex. '));
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_controllers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No confirmation points added. Click "Add Point" to create one.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                  ),
                )
              else
                for (int i = 0; i < _controllers.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10, right: 8),
                          child: Text(
                            '${i + 1}.',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _controllers[i],
                            maxLines: null,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Enter confirmation text for point ${i + 1}',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          tooltip: 'Delete Point',
                          onPressed: () {
                            setState(() {
                              final removed = _controllers.removeAt(i);
                              removed.dispose();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF174895),
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(_isSaving ? 'Saving...' : 'Save Confirmations'),
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
