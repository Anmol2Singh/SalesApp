// lib/core/widgets/export_preview_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class ExportPreviewDialog extends StatelessWidget {
  final String title;
  final String fileName;
  final List<String> headers;
  final List<List<String>> rows;
  final List<int> fileBytes;

  const ExportPreviewDialog({
    super.key,
    required this.title,
    required this.fileName,
    required this.headers,
    required this.rows,
    required this.fileBytes,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
    required List<int> fileBytes,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExportPreviewDialog(
        title: title,
        fileName: fileName,
        headers: headers,
        rows: rows,
        fileBytes: fileBytes,
      ),
    );
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(fileBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '$title — ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _downloadFile(BuildContext context) async {
    final safeName = fileName.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');
    try {
      File? savedFile;
      String locationName = 'Downloads';

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        Directory? winDownloads;
        if (userProfile != null) {
          final candidate = Directory('$userProfile\\Downloads');
          if (candidate.existsSync()) winDownloads = candidate;
        }
        winDownloads ??= await getDownloadsDirectory();
        if (winDownloads != null) {
          savedFile = File('${winDownloads.path}/$safeName');
          await savedFile.writeAsBytes(fileBytes, flush: true);
          locationName = 'Downloads folder';
          try {
            Process.run('explorer.exe', ['/select,', savedFile.path]);
          } catch (_) {}
        }
      } else if (Platform.isAndroid) {
        bool savedDirectly = false;
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (downloadDir.existsSync()) {
            final target = File('${downloadDir.path}/$safeName');
            await target.writeAsBytes(fileBytes, flush: true);
            savedFile = target;
            savedDirectly = true;
            locationName = 'Downloads folder';
          }
        } catch (_) {}

        if (!savedDirectly) {
          // Save to cache/documents and invoke system save sheet
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$safeName');
          await tempFile.writeAsBytes(fileBytes, flush: true);
          savedFile = tempFile;

          await Share.shareXFiles(
            [XFile(tempFile.path)],
            subject: safeName,
          );
          locationName = 'Device Storage';
        }
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        savedFile = File('${docsDir.path}/$safeName');
        await savedFile.writeAsBytes(fileBytes, flush: true);
        locationName = 'Documents';
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved successfully to $locationName ($safeName)'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () {
                if (savedFile != null) {
                  Share.shareXFiles([XFile(savedFile.path)]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_chart_outlined, color: Color(0xFF0284C7), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$fileName • ${rows.length} ${rows.length == 1 ? 'record' : 'records'}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Preview Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF1E1B4B)),
                    headingTextStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                    dataTextStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    border: TableBorder.all(color: AppColors.border.withOpacity(0.6), width: 0.5),
                    columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
                    rows: rows.map((row) {
                      return DataRow(
                        cells: row.map((cell) => DataCell(Text(cell.isEmpty ? '-' : cell))).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Action Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
                      label: const Text(
                        'Download',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                      onPressed: () => _downloadFile(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 20, color: Colors.white),
                      label: const Text(
                        'Share File',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () => _shareFile(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
