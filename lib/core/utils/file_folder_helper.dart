// lib/core/utils/file_folder_helper.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class FileFolderHelper {
  static const MethodChannel _channel = MethodChannel('com.izyheat.salesapp/file_folder');

  /// Opens the folder containing the downloaded file or the default Downloads folder.
  /// - On Windows PC: Opens explorer.exe with the file selected.
  /// - On macOS: Opens Finder with the file selected.
  /// - On Linux: Opens the file manager.
  /// - On Android: Uses native platform channel to launch Downloads intent.
  /// - On iOS: Opens Files app.
  static Future<void> openFolder({String? filePath, String? folderPath}) async {
    if (kIsWeb) return;

    try {
      if (Platform.isWindows) {
        if (filePath != null && File(filePath).existsSync()) {
          await Process.run('explorer.exe', ['/select,', filePath]);
          return;
        }
        if (folderPath != null && Directory(folderPath).existsSync()) {
          await Process.run('explorer.exe', [folderPath]);
          return;
        }
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final winDownloads = '$userProfile\\Downloads';
          if (Directory(winDownloads).existsSync()) {
            await Process.run('explorer.exe', [winDownloads]);
            return;
          }
        }
        await Process.run('explorer.exe', []);
      } else if (Platform.isMacOS) {
        if (filePath != null && File(filePath).existsSync()) {
          await Process.run('open', ['-R', filePath]);
          return;
        }
        if (folderPath != null && Directory(folderPath).existsSync()) {
          await Process.run('open', [folderPath]);
          return;
        }
      } else if (Platform.isLinux) {
        if (folderPath != null && Directory(folderPath).existsSync()) {
          await Process.run('xdg-open', [folderPath]);
          return;
        }
      } else if (Platform.isAndroid) {
        bool opened = false;
        try {
          final res = await _channel.invokeMethod<bool>('openDownloadFolder');
          if (res == true) opened = true;
        } catch (_) {}

        if (!opened) {
          try {
            final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
              opened = true;
            }
          } catch (_) {}
        }

        if (!opened && filePath != null && File(filePath).existsSync()) {
          await Share.shareXFiles([XFile(filePath)]);
        }
      } else if (Platform.isIOS) {
        if (filePath != null && File(filePath).existsSync()) {
          await Share.shareXFiles([XFile(filePath)]);
        }
      }
    } catch (e) {
      debugPrint('Error opening folder: $e');
    }
  }

  /// Prompts the user: "Would you like to view in folder?"
  /// If confirmed, immediately leads them to the folder (PC or Mobile).
  static Future<void> askViewInFolder(
    BuildContext context, {
    required String fileName,
    required String locationName,
    required String filePath,
    required String folderPath,
  }) async {
    if (!context.mounted) return;

    // Show prompt dialog asking "View in folder?"
    final shouldOpen = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
            SizedBox(width: 10),
            Text(
              'Download Complete',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved to $locationName:',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              fileName,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to view it in folder?',
              style: TextStyle(fontFamily: 'Inter', fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.folder_open, color: Colors.white, size: 18),
            label: const Text('View in Folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await openFolder(filePath: filePath, folderPath: folderPath);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Saved to $locationName ($fileName)'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View in Folder',
            textColor: Colors.white,
            onPressed: () => openFolder(filePath: filePath, folderPath: folderPath),
          ),
        ),
      );
    }
  }
}
