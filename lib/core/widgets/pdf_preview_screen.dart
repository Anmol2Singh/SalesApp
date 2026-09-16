import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

class PdfPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isSaving = false;

  String get _safeFileName => widget.fileName.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');

  Future<void> _downloadFile() async {
    setState(() => _isSaving = true);
    final safeName = _safeFileName;
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        Directory? winDownloads;
        if (userProfile != null) {
          final candidate = Directory('$userProfile\\Downloads');
          if (candidate.existsSync()) winDownloads = candidate;
        }
        winDownloads ??= await getDownloadsDirectory();
        if (winDownloads != null) {
          final file = File('${winDownloads.path}/$safeName');
          await file.writeAsBytes(widget.pdfBytes, flush: true);
          try {
            Process.run('explorer.exe', ['/select,', file.path]);
          } catch (_) {}

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ Downloaded to Downloads folder: $safeName'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      if (Platform.isAndroid) {
        bool savedDirectly = false;
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (downloadDir.existsSync()) {
            final target = File('${downloadDir.path}/$safeName');
            await target.writeAsBytes(widget.pdfBytes, flush: true);
            savedDirectly = true;
          }
        } catch (_) {}

        if (savedDirectly) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ Downloaded to device storage: $safeName'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Share',
                  textColor: Colors.white,
                  onPressed: () => _shareFile(),
                ),
              ),
            );
          }
          return;
        }

        // On Android Scoped Storage: use Printing.sharePdf to open native system Save/Print sheet
        await Printing.sharePdf(
          bytes: widget.pdfBytes,
          filename: safeName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Choose "Save to Downloads" or viewer for $safeName'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(widget.pdfBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved: $safeName'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _shareFile(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareFile() async {
    final safeName = _safeFileName;
    try {
      await Printing.sharePdf(bytes: widget.pdfBytes, filename: safeName);
    } catch (e) {
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$safeName');
        await tempFile.writeAsBytes(widget.pdfBytes);
        await Share.shareXFiles([XFile(tempFile.path)], text: 'Document: $safeName');
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to share: $err'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _printFile() async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => widget.pdfBytes,
        name: widget.fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PdfPreview(
                  build: (format) => widget.pdfBytes,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  previewPageMargin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          
          // Action Buttons Bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _downloadFile,
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download, size: 18),
                          label: const Text('Download', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _printFile,
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareFile,
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
