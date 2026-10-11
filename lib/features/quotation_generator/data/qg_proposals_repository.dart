// lib/features/quotation_generator/data/qg_proposals_repository.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing module-owned proposals.
/// Direct table writes to qg_proposals are prohibited by RLS; all finalizations
/// are strictly mediated by the SECURITY DEFINER RPC `qg_finalize_proposal`.
/// Storage uploads are restricted to private bucket `quotation-generator`.
class QgProposalsRepository {
  final SupabaseClient _supabase;

  QgProposalsRepository(this._supabase);

  static const String bucketName = 'quotation-generator';

  /// Fetches the latest active finalized proposal for a quotation.
  Future<Map<String, dynamic>?> getActiveProposal(String quotationId) async {
    try {
      final res = await _supabase
          .from('qg_proposals')
          .select()
          .eq('quotation_id', quotationId)
          .eq('is_current', true)
          .maybeSingle();

      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('QgProposalsRepository.getActiveProposal error: $e');
      return null;
    }
  }

  /// Fetches the full version history of proposals for a quotation.
  Future<List<Map<String, dynamic>>> getProposalHistory(String quotationId) async {
    try {
      final res = await _supabase
          .from('qg_proposals')
          .select()
          .eq('quotation_id', quotationId)
          .order('version', ascending: false);

      return res.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('QgProposalsRepository.getProposalHistory error: $e');
      return [];
    }
  }

  /// Finalizes and commits a proposal via the SECURITY DEFINER RPC.
  /// Server-side validation guarantees approval gating (quotations.status == 'confirmed').
  Future<Map<String, dynamic>> finalizeProposal({
    required String quotationId,
    required Map<String, dynamic> payload,
    required String pdfPath,
    required String refNo,
  }) async {
    try {
      final res = await _supabase.rpc(
        'qg_finalize_proposal',
        params: {
          'p_quotation_id': quotationId,
          'p_payload': payload,
          'p_pdf_path': pdfPath,
          'p_ref_no': refNo,
        },
      );

      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': true, 'data': res};
    } catch (e) {
      debugPrint('QgProposalsRepository.finalizeProposal RPC error: $e');
      rethrow;
    }
  }

  /// Uploads generated PDF bytes to the private `quotation-generator` bucket.
  Future<String?> uploadProposalPdf({
    required String quotationId,
    required String refNo,
    required Uint8List pdfBytes,
  }) async {
    try {
      final sanitizedRef = refNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final path = 'proposals/$quotationId/proposal_${sanitizedRef}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await _supabase.storage.from(bucketName).uploadBinary(
        path,
        pdfBytes,
        fileOptions: const FileOptions(
          contentType: 'application/pdf',
          upsert: true,
        ),
      );

      return path;
    } catch (e) {
      debugPrint('QgProposalsRepository.uploadProposalPdf error: $e');
      return null;
    }
  }

  /// Generates a temporary signed URL for viewing/downloading the private PDF.
  Future<String?> getSignedPdfUrl(String pdfPath, {int expiresInSeconds = 3600}) async {
    try {
      final signedUrl = await _supabase.storage.from(bucketName).createSignedUrl(
        pdfPath,
        expiresInSeconds,
      );
      return signedUrl;
    } catch (e) {
      debugPrint('QgProposalsRepository.getSignedPdfUrl error: $e');
      return null;
    }
  }
}
