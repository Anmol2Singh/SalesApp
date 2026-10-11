// lib/features/quotation_generator/services/quotation_storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/quotation_generator_flags.dart';

class QuotationStorageService {
  /// Uploads a local file or image bytes to Supabase Storage and returns the public URL.
  static Future<String?> uploadImageFile({
    required SupabaseClient supabase,
    required File file,
    String bucket = 'company-assets',
    String folder = 'quotations',
  }) async {
    if (kDisableUnsafeExistingWrites &&
        (bucket == 'company-assets' || bucket == 'product-images' || bucket == 'pdfs')) {
      debugPrint('[CONTAINMENT GUARD] uploadImageFile: Uploads to legacy bucket "$bucket" are disabled.');
      return null;
    }
    try {
      final ext = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : 'jpg';
      final fileName = '$folder/${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.$ext';
      final bytes = await file.readAsBytes();

      String contentType = 'image/jpeg';
      if (ext == 'png') contentType = 'image/png';
      if (ext == 'webp') contentType = 'image/webp';

      await supabase.storage.from(bucket).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from(bucket).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('QuotationStorageService.uploadImageFile error: $e');
      return null;
    }
  }

  /// Uploads generated PDF bytes to Supabase Storage bucket `pdfs` and returns the public URL.
  static Future<String?> uploadQuotationPdf({
    required SupabaseClient supabase,
    required Uint8List pdfBytes,
    required String quotationNumber,
  }) async {
    if (kDisableUnsafeExistingWrites) {
      debugPrint('[CONTAINMENT GUARD] uploadQuotationPdf: Uploads to legacy bucket "pdfs" are disabled.');
      return null;
    }
    try {
      final cleanRef = quotationNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'quotation_${cleanRef}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await supabase.storage.from('pdfs').uploadBinary(
        fileName,
        pdfBytes,
        fileOptions: const FileOptions(
          contentType: 'application/pdf',
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from('pdfs').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('QuotationStorageService.uploadQuotationPdf error: $e');
      return null;
    }
  }
}
