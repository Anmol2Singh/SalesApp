// lib/features/customers/screens/customer_documents_screen.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/customer_document.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/customer_documents_service.dart';

class CustomerDocumentsScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerDocumentsScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  ConsumerState<CustomerDocumentsScreen> createState() =>
      _CustomerDocumentsScreenState();
}

class _CustomerDocumentsScreenState
    extends ConsumerState<CustomerDocumentsScreen> {
  List<CustomerDocument>? _documents;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final supabase = ref.read(supabaseClientProvider);
      final list = await CustomerDocumentsService.fetchDocuments(
        supabase: supabase,
        customerId: widget.customerId,
      );
      if (mounted) {
        setState(() {
          _documents = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showAddDocumentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDocumentSheet(
        customerId: widget.customerId,
        onUploaded: () {
          _loadDocuments();
        },
      ),
    );
  }

  Future<void> _previewDocument(CustomerDocument doc) async {
    final supabase = ref.read(supabaseClientProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final bytes = await CustomerDocumentsService.getFileBytes(
        supabase: supabase,
        document: doc,
      );
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (doc.isPdf) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: bytes,
              fileName: doc.fileName,
            ),
          ),
        );
      } else {
        // Image preview
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(CustomerDocument doc) async {
    final supabase = ref.read(supabaseClientProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${doc.title}"...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      await CustomerDocumentsService.downloadDocument(
        supabase: supabase,
        document: doc,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Saved to Downloads: ${doc.fileName}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _shareDocument(CustomerDocument doc) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      await CustomerDocumentsService.shareDocument(
        supabase: supabase,
        document: doc,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(CustomerDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text(
          'Are you sure you want to permanently delete "${doc.title}" (${doc.fileName})? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await CustomerDocumentsService.deleteDocument(
        supabase: supabase,
        document: doc,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final userRoles = profile?.roles ?? (profile != null ? [profile.primaryRole] : <UserRole>[]);
    final isAdmin = userRoles.contains(UserRole.admin);
    final isSalesHead = userRoles.contains(UserRole.salesHead);
    final isManager = userRoles.contains(UserRole.manager);

    // Permission guard: strictly for admins, sales head, managers (NOT customer login)
    final canAccess = isAdmin || isSalesHead || isManager;

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supporting Documents')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Access Restricted: Only Admin and Sales Head can view customer supporting documents.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 15),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supporting Documents',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.customerName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text('Error: $_errorMessage'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDocuments,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _documents == null || _documents!.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.folder_open_outlined,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Supporting Documents',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Upload contracts, ID proofs, site photos, or specifications for this customer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showAddDocumentSheet(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Upload First Document'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDocuments,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _documents!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = _documents![index];
                          final isPdf = doc.isPdf;

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  // Leading Document Type Icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isPdf
                                          ? Colors.red.shade50
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isPdf
                                            ? Icons.picture_as_pdf
                                            : Icons.image_outlined,
                                        color: isPdf
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Document Title and Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.title,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${doc.fileName} • ${_formatFileSize(doc.fileSize)}',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('dd MMM yyyy, hh:mm a')
                                              .format(doc.createdAt),
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10.5,
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action Icons ONLY: [preview, download, share] (and delete for admin)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        tooltip: 'Preview',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _previewDocument(doc),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.download_outlined,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        tooltip: 'Download',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _downloadDocument(doc),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.share_outlined,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        tooltip: 'Share',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _shareDocument(doc),
                                      ),
                                      if (isAdmin)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: Colors.redAccent,
                                          ),
                                          tooltip: 'Delete',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _deleteDocument(doc),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _showAddDocumentSheet(context),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              '+ Add Document',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddDocumentSheet extends ConsumerStatefulWidget {
  final String customerId;
  final VoidCallback onUploaded;

  const _AddDocumentSheet({
    required this.customerId,
    required this.onUploaded,
  });

  @override
  ConsumerState<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends ConsumerState<_AddDocumentSheet> {
  final _titleController = TextEditingController();
  String? _selectedFilePath;
  String? _selectedFileName;
  int _selectedFileSize = 0;
  String _fileType = 'pdf'; // 'pdf' or 'image'
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String type) async {
    try {
      final files = await FilePicker.pickFiles(
        type: type == 'pdf' ? FileType.custom : FileType.image,
        allowedExtensions: type == 'pdf' ? ['pdf'] : null,
      );

      if (files.isNotEmpty && files.first.path != null) {
        final filePath = files.first.path!;
        final name = files.first.name;
        final file = File(filePath);
        final size = await file.length();

        setState(() {
          _selectedFilePath = filePath;
          _selectedFileName = name;
          _selectedFileSize = size;
          _fileType = type;
          if (_titleController.text.trim().isEmpty) {
            final dotIdx = name.lastIndexOf('.');
            _titleController.text = dotIdx > 0 ? name.substring(0, dotIdx) : name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _upload() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for the document'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Image or PDF file to upload'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final file = File(_selectedFilePath!);
    if (!file.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected file could not be found'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final fileBytes = await file.readAsBytes();
    if (fileBytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected file data could not be read'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await CustomerDocumentsService.uploadDocument(
        supabase: supabase,
        customerId: widget.customerId,
        title: title,
        fileName: _selectedFileName ?? 'document',
        fileBytes: fileBytes,
        fileType: _fileType,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close sheet
      widget.onUploaded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Document uploaded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upload Supporting Document',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Document Title *',
                hintText: 'e.g. Site Agreement, Electricity Bill, Aadhaar',
                prefixIcon: const Icon(Icons.title_outlined, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // File pickers
            const Text(
              'Select File (Image or PDF):',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFile('pdf'),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    label: const Text('Pick PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFile('image'),
                    icon: const Icon(Icons.image, color: Colors.blue),
                    label: const Text('Pick Image'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedFilePath != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _fileType == 'pdf'
                          ? Icons.picture_as_pdf
                          : Icons.image,
                      color: _fileType == 'pdf' ? Colors.red : Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName ?? 'document',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Size: ${(_selectedFileSize / 1024).toStringAsFixed(1)} KB',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _selectedFilePath = null;
                        _selectedFileName = null;
                        _selectedFileSize = 0;
                      }),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _upload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isUploading ? 'Uploading...' : 'Upload Document',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
