import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../../providers/pm_company_provider.dart';
import '../../providers/pm_providers.dart';
import 'pm_pdf_columns_config_dialog.dart';

class PmAppSettingsDialog extends ConsumerStatefulWidget {
  const PmAppSettingsDialog({super.key});

  @override
  ConsumerState<PmAppSettingsDialog> createState() => _PmAppSettingsDialogState();
}

class _PmAppSettingsDialogState extends ConsumerState<PmAppSettingsDialog> {
  String _saveLocation = r'D:\Solar Reports';
  bool _isBackingUp = false;
  bool _isRestoring = false;

  Future<void> _handleSetLocation() async {
    final selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() => _saveLocation = selectedDirectory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save location updated to: $_saveLocation')),
        );
      }
    }
  }

  Future<void> _handleBackup() async {
    final activeCompany = ref.read(pmActiveCompanyProvider);
    setState(() => _isBackingUp = true);

    try {
      final projects = await ref.read(pmProjectsRepositoryProvider).getProjects(companyId: activeCompany.id);
      final purchases = await ref.read(pmPurchasesRepositoryProvider).getPurchases(companyId: activeCompany.id);

      final backupData = {
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'company': activeCompany.toJson(),
        'projects': projects.map((p) => p.toJson()).toList(),
        'purchases': purchases.map((p) => p.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final bytes = utf8.encode(jsonString);

      await Printing.sharePdf(
        bytes: bytes,
        filename: '${activeCompany.name.replaceAll(' ', '_')}_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestore() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      setState(() => _isRestoring = true);
      try {
        final file = File(files.first.path!);
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        final projectsList = data['projects'] as List<dynamic>? ?? [];
        for (final item in projectsList) {
          final map = Map<String, dynamic>.from(item as Map);
          map.remove('id');
          await ref.read(pmProjectsRepositoryProvider).createProject(map);
        }

        ref.invalidate(pmProjectsListProvider);
        ref.invalidate(pmPurchasesListProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully restored ${projectsList.length} records!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isRestoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCompany = ref.watch(pmActiveCompanyProvider);
    final companies = ref.watch(pmCompaniesListProvider);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header: Blue Gear Icon + Title + Close X
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(LucideIcons.settings, size: 20, color: Color(0xFF005CE6)),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'App Settings & Company Management',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Database Backup & Storage Card (Screenshot 1)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCCFBF1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(LucideIcons.database, size: 16, color: Color(0xFF0284C7)),
                                SizedBox(width: 8),
                                Text(
                                  'Database Backup & Storage',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // PC Save Folder Location
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('PC Save Folder Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 2),
                                      Text('Default: $_saveLocation', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: _handleSetLocation,
                                  borderRadius: BorderRadius.circular(9999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(9999),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.folder, size: 13, color: Color(0xFFD97706)),
                                        SizedBox(width: 6),
                                        Text('Set Location', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFFE2E8F0), height: 1),
                            const SizedBox(height: 12),

                            // Download Backup (.json)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Download Backup (.json)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                      const SizedBox(height: 2),
                                      Text('Full JSON data for ${activeCompany.name}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: _isBackingUp ? null : _handleBackup,
                                  borderRadius: BorderRadius.circular(9999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF005CE6),
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.download, size: 13, color: Colors.white),
                                        const SizedBox(width: 6),
                                        Text(_isBackingUp ? 'Exporting...' : 'Backup', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFFE2E8F0), height: 1),
                            const SizedBox(height: 12),

                            // Restore Database (.json)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Restore Database (.json)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                      SizedBox(height: 2),
                                      Text('Upload previously exported backup', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: _isRestoring ? null : _handleRestore,
                                  borderRadius: BorderRadius.circular(9999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(9999),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.cloudUpload, size: 13, color: Color(0xFF005CE6)),
                                        const SizedBox(width: 6),
                                        Text(_isRestoring ? 'Restoring...' : 'Restore', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 2: PDF Export Columns
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PDF Export Columns', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                  SizedBox(height: 2),
                                  Text(
                                    'Choose columns for Directory PDF',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => const PmPdfColumnsConfigDialog(),
                                );
                              },
                              borderRadius: BorderRadius.circular(9999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9999),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Text('Configure', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 4: MANAGE CREATED COMPANIES (Screenshot 1)
                      const Row(
                        children: [
                          Icon(LucideIcons.building2, size: 16, color: Color(0xFF005CE6)),
                          SizedBox(width: 8),
                          Text(
                            'MANAGE CREATED COMPANIES',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Company Cards
                      ...companies.map((c) {
                        final isActive = c.id == activeCompany.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isActive ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    ref.read(pmActiveCompanyProvider.notifier).setCompany(c);
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            c.name,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                          ),
                                          if (isActive) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFBFDBFE),
                                                borderRadius: BorderRadius.circular(9999),
                                              ),
                                              child: const Text('Active', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.tagline ?? 'Project Manager',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
                                    SizedBox(width: 4),
                                    Text('Delete', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                                  ],
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Cannot delete default system company: ${c.name}')),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Close Button
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
