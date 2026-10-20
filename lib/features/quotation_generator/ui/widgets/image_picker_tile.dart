// lib/features/quotation_generator/ui/widgets/image_picker_tile.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/quotation_storage_service.dart';

class ImagePickerTile extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final String? currentPath;
  final String defaultAssetPath;
  final String bucket;
  final String folder;
  final ValueChanged<String?> onImageChanged;
  final VoidCallback onResetToDefault;

  const ImagePickerTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentPath,
    required this.defaultAssetPath,
    this.bucket = 'company-assets',
    this.folder = 'quotations',
    required this.onImageChanged,
    required this.onResetToDefault,
  });

  @override
  ConsumerState<ImagePickerTile> createState() => _ImagePickerTileState();
}

class _ImagePickerTileState extends ConsumerState<ImagePickerTile> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final supabase = ref.read(supabaseClientProvider);
      final bytes = await picked.readAsBytes();

      final publicUrl = await QuotationStorageService.uploadImageBytes(
        supabase: supabase,
        bytes: bytes,
        fileName: picked.name,
        bucket: widget.bucket,
        folder: widget.folder,
      );

      if (mounted) {
        setState(() => _isUploading = false);
      }

      if (publicUrl != null) {
        widget.onImageChanged(publicUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ${widget.title} uploaded to Supabase Storage!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Fallback to local path if storage upload encountered an error
        widget.onImageChanged(picked.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick/upload image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCustom = widget.currentPath != null && widget.currentPath != widget.defaultAssetPath;

    Widget imageWidget;
    final current = widget.currentPath;

    if (current != null && current.startsWith('http')) {
      imageWidget = Image.network(
        current,
        fit: _containOrCover(widget.title),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
        },
        errorBuilder: (_, __, ___) => Image.asset(widget.defaultAssetPath, fit: _containOrCover(widget.title)),
      );
    } else if (current != null && !current.startsWith('assets/')) {
      if (current.startsWith('blob:') || current.startsWith('data:')) {
        imageWidget = Image.network(current, fit: _containOrCover(widget.title));
      } else if (!kIsWeb) {
        final file = File(current);
        if (file.existsSync()) {
          imageWidget = Image.file(file, fit: _containOrCover(widget.title));
        } else {
          imageWidget = Image.asset(widget.defaultAssetPath, fit: _containOrCover(widget.title));
        }
      } else {
        imageWidget = Image.asset(widget.defaultAssetPath, fit: _containOrCover(widget.title));
      }
    } else {
      imageWidget = Image.asset(widget.defaultAssetPath, fit: _containOrCover(widget.title));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCustom ? AppColors.accent : (isDark ? Colors.white12 : AppColors.border),
          width: isCustom ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail / Loading indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 72,
              height: 72,
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              child: _isUploading
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
                  : imageWidget,
            ),
          ),
          const SizedBox(width: 14),
          // Info & Actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    if (isCustom)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (current != null && current.startsWith('http')) ? 'Supabase' : 'Custom',
                          style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickAndUploadImage,
                      icon: _isUploading
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                          : const Icon(Icons.cloud_upload_outlined, size: 15),
                      label: Text(_isUploading ? 'Uploading...' : 'Change', style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onResetToDefault,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Reset', style: TextStyle(fontSize: 12, color: AppColors.error)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxFit _containOrCover(String title) {
    if (title.toLowerCase().contains('stamp') || title.toLowerCase().contains('product')) {
      return BoxFit.contain;
    }
    return BoxFit.cover;
  }
}
