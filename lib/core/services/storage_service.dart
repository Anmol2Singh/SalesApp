// lib/core/services/storage_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const String bucketName = 'complaint-photos';

  /// Uploads a base64 or raw image bytes to Supabase Storage bucket `complaints_photo`
  /// and returns the public URL string.
  static Future<String?> uploadImage({
    required SupabaseClient supabase,
    required String base64OrPath,
    String folder = 'issue_photos',
  }) async {
    try {
      Uint8List bytes;
      String extension = 'jpg';

      if (base64OrPath.startsWith('data:image')) {
        final commaIdx = base64OrPath.indexOf(',');
        final mimePart = base64OrPath.substring(0, commaIdx);
        if (mimePart.contains('png')) extension = 'png';
        if (mimePart.contains('webp')) extension = 'webp';
        final cleanBase64 = base64OrPath.substring(commaIdx + 1);
        bytes = base64Decode(cleanBase64);
      } else {
        bytes = base64Decode(base64OrPath);
      }

      final fileName = '$folder/${Uuid().v4()}.$extension';
      
      await supabase.storage.from(bucketName).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$extension',
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from(bucketName).getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  /// Uploads a list of base64 images to Supabase Storage and returns a list of public URLs.
  static Future<List<String>> uploadMultipleImages({
    required SupabaseClient supabase,
    required List<String> base64OrPaths,
    String folder = 'issue_photos',
  }) async {
    final List<String> urls = [];
    for (final item in base64OrPaths) {
      if (item.startsWith('http')) {
        urls.add(item);
      } else {
        final url = await uploadImage(
          supabase: supabase,
          base64OrPath: item,
          folder: folder,
        );
        if (url != null) urls.add(url);
      }
    }
    return urls;
  }
}
