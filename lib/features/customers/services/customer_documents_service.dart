// lib/features/customers/services/customer_documents_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/customer_document.dart';

class CustomerDocumentsService {
  static const String bucketName = 'customer-documents';

  /// Ensures the storage bucket exists in Supabase.
  static Future<void> ensureBucket(SupabaseClient supabase) async {
    try {
      await supabase.storage.createBucket(
        bucketName,
        const BucketOptions(public: true),
      );
    } catch (_) {
      // Ignored if bucket already exists
    }
  }

  /// Fetches all supporting documents for a specific customer.
  static Future<List<CustomerDocument>> fetchDocuments({
    required SupabaseClient supabase,
    required String customerId,
  }) async {
    try {
      final res = await supabase
          .from('customer_documents')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      final list = (res as List<dynamic>)
          .map((json) => CustomerDocument.fromJson(json as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      debugPrint('Error fetching customer documents: $e');
      return [];
    }
  }

  /// Uploads a document (PDF or image) to Supabase Storage and records metadata.
  static Future<CustomerDocument> uploadDocument({
    required SupabaseClient supabase,
    required String customerId,
    required String title,
    required String fileName,
    required Uint8List fileBytes,
    required String fileType, // 'pdf' or 'image'
  }) async {
    await ensureBucket(supabase);

    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : (fileType == 'pdf' ? 'pdf' : 'jpg');
    final cleanFileName = fileName.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');
    final uniqueId = const Uuid().v4();
    final storagePath = '$customerId/${uniqueId}_$cleanFileName';

    String mimeType = 'application/octet-stream';
    if (ext == 'pdf') {
      mimeType = 'application/pdf';
    } else if (ext == 'png') {
      mimeType = 'image/png';
    } else if (ext == 'jpg' || ext == 'jpeg') {
      mimeType = 'image/jpeg';
    } else if (ext == 'webp') {
      mimeType = 'image/webp';
    }

    // 1. Upload bytes to storage
    await supabase.storage.from(bucketName).uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    // 2. Get Public URL
    final publicUrl = supabase.storage.from(bucketName).getPublicUrl(storagePath);

    // 3. Insert record into customer_documents table
    final currentUser = supabase.auth.currentUser;
    final row = await supabase
        .from('customer_documents')
        .insert({
          'customer_id': customerId,
          'title': title.trim(),
          'file_url': publicUrl,
          'file_path': storagePath,
          'file_name': cleanFileName,
          'file_type': fileType,
          'file_size': fileBytes.lengthInBytes,
          'created_by': currentUser?.id,
        })
        .select()
        .single();

    return CustomerDocument.fromJson(row);
  }

  /// Deletes a document from storage and metadata database.
  static Future<void> deleteDocument({
    required SupabaseClient supabase,
    required CustomerDocument document,
  }) async {
    try {
      if (document.filePath.isNotEmpty) {
        await supabase.storage.from(bucketName).remove([document.filePath]);
      }
    } catch (e) {
      debugPrint('Warning: Could not delete file from storage: $e');
    }

    await supabase.from('customer_documents').delete().eq('id', document.id);
  }

  /// Downloads file bytes from storage or URL.
  static Future<Uint8List> getFileBytes({
    required SupabaseClient supabase,
    required CustomerDocument document,
  }) async {
    if (document.filePath.isNotEmpty) {
      try {
        final bytes = await supabase.storage.from(bucketName).download(document.filePath);
        return bytes;
      } catch (_) {}
    }
    final resp = await http.get(Uri.parse(document.fileUrl));
    if (resp.statusCode == 200) {
      return resp.bodyBytes;
    }
    throw Exception('Failed to download document (${resp.statusCode})');
  }

  /// Saves document locally to user's device Downloads directory.
  static Future<String> downloadDocument({
    required SupabaseClient supabase,
    required CustomerDocument document,
  }) async {
    final bytes = await getFileBytes(supabase: supabase, document: document);
    final safeName = document.fileName.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');

    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!dir.existsSync()) {
        dir = await getExternalStorageDirectory();
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final candidate = Directory('$userProfile\\Downloads');
        if (candidate.existsSync()) dir = candidate;
      }
      dir ??= await getDownloadsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    dir ??= await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$safeName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// Shares document via system share dialog.
  static Future<void> shareDocument({
    required SupabaseClient supabase,
    required CustomerDocument document,
  }) async {
    if (kIsWeb) {
      await Share.shareUri(Uri.parse(document.fileUrl));
      return;
    }
    final bytes = await getFileBytes(supabase: supabase, document: document);
    final tempDir = await getTemporaryDirectory();
    final safeName = document.fileName.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');
    final tempFile = File('${tempDir.path}/$safeName');
    await tempFile.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(tempFile.path)],
      text: document.title,
    );
  }
}
