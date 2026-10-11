// lib/features/quotation_generator/services/quotation_storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Legacy storage service (retired in v2).
/// All proposal assets and PDFs in v2 are managed by `QgProposalsRepository`
/// targeting exclusively the private module bucket `quotation-generator`.
class QuotationStorageService {
  /// Retired legacy upload: no-op to protect legacy buckets.
  static Future<String?> uploadImageFile({
    required SupabaseClient supabase,
    required File file,
    String bucket = 'quotation-generator',
    String folder = 'temp',
  }) async {
    debugPrint('[CONTAINMENT GUARD] Legacy image upload retired. Storage operations are managed by QgProposalsRepository.');
    return null;
  }

  /// Retired legacy upload: no-op to protect legacy bucket `pdfs`.
  static Future<String?> uploadQuotationPdf({
    required SupabaseClient supabase,
    required Uint8List pdfBytes,
    required String quotationNumber,
  }) async {
    debugPrint('[CONTAINMENT GUARD] Legacy PDF upload retired. Storage operations are managed by QgProposalsRepository.');
    return null;
  }
}
