// lib/features/quotation_generator/services/quotation_storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class QuotationStorageService {
  /// Upload image bytes directly to Supabase storage. Safe for Flutter Web and all platforms.
  static Future<String?> uploadImageBytes({
    required SupabaseClient supabase,
    required Uint8List bytes,
    required String fileName,
    String bucket = 'company-assets',
    String folder = 'branding',
  }) async {
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'png';
      final cleanExt = (ext == 'jpg' || ext == 'jpeg') ? 'jpeg' : (ext == 'png' ? 'png' : 'webp');
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.$ext';
      final storagePath = '$folder/$uniqueName';

      await supabase.storage.from(bucket).uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$cleanExt',
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from(bucket).getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('QuotationStorageService.uploadImageBytes error: $e');
      return null;
    }
  }

  /// Upload file using local File (non-web)
  static Future<String?> uploadImageFile({
    required SupabaseClient supabase,
    required File file,
    String bucket = 'company-assets',
    String folder = 'branding',
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final fileName = file.path.split(Platform.pathSeparator).last;
      return uploadImageBytes(
        supabase: supabase,
        bytes: bytes,
        fileName: fileName,
        bucket: bucket,
        folder: folder,
      );
    } catch (e) {
      debugPrint('QuotationStorageService.uploadImageFile error: $e');
      return null;
    }
  }

  static Future<String?> uploadQuotationPdf({
    required SupabaseClient supabase,
    required Uint8List pdfBytes,
    required String quotationNumber,
  }) async {
    try {
      final cleanNum = quotationNumber.replaceAll('/', '_');
      final path = 'quotations/$cleanNum.pdf';
      await supabase.storage.from('quotation-generator').uploadBinary(
        path,
        pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
      );
      return supabase.storage.from('quotation-generator').getPublicUrl(path);
    } catch (e) {
      debugPrint('QuotationStorageService.uploadQuotationPdf error: $e');
      return null;
    }
  }
}
