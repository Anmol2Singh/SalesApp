// lib/features/admin/screens/product_catalog_screen.dart
// Stub — product viewing + basic management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/utils/file_folder_helper.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';

final productDealCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final response = await supabase.from('sales_pipelines').select('product_id');
    final Map<String, int> counts = {};
    for (final row in response as List) {
      final pid = row['product_id'] as String?;
      if (pid != null) {
        counts[pid] = (counts[pid] ?? 0) + 1;
      }
    }
    return counts;
  } catch (_) {
    return {};
  }
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  if (supabaseUrl.contains('your-project-ref')) {
    final now = DateTime.now();
    return [
      Product(
        id: 'p1',
        name: 'Boom Barrier (Heavy Duty)',
        category: 'Security',
        baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: 'p2',
        name: 'IZYHEAT Commercial Heat Pump',
        category: 'Heating',
        baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  final response = await supabase
      .from('products')
      .select()
      .isFilter('deleted_at', null)
      .order('name');

  return (response as List<dynamic>)
      .map((json) => Product.fromJson(json as Map<String, dynamic>))
      .toList();
});

class ProductCatalogScreen extends ConsumerWidget {
  final bool isEmbedded;
  final bool isViewOnly;
  const ProductCatalogScreen({
    super.key,
    this.isEmbedded = false,
    this.isViewOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = (profile?.primaryRole == UserRole.admin) && !isViewOnly;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isEmbedded ? null : AppBar(
        title: const Text('Product Catalog'),
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(
              child: Text(
                'No products configured.\nRun the seed migration to add sample products.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: product.isActive ? AppColors.border : AppColors.textDisabled,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                product.category ?? 'Uncategorized',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.isActive
                                ? AppColors.successLight
                                : AppColors.errorLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: product.isActive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showEditProductDialog(context, ref, product);
                              } else if (val == 'delete') {
                                _showDeleteProductDialog(context, ref, product);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit Product'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete Product', style: TextStyle(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 10),
                    Consumer(
                      builder: (context, ref, _) {
                        final dealCountsAsync = ref.watch(productDealCountsProvider);
                        final dealCount = dealCountsAsync.value?[product.id] ?? 0;
                        return Text(
                          '$dealCount active deal${dealCount == 1 ? "" : "s"}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Images Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Product Photos (${product.imageUrls.length})',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isAdmin)
                          InkWell(
                            onTap: () => _uploadImage(context, ref, product),
                            child: const Row(
                              children: [
                                Icon(Icons.add_a_photo_outlined, size: 16, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text('Add Photo', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (product.imageUrls.isEmpty)
                      const Text('No photos uploaded yet.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary))
                    else
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: product.imageUrls.length,
                          itemBuilder: (ctx, imgIdx) {
                            final url = product.imageUrls[imgIdx];
                            return GestureDetector(
                              onTap: () => _showImagePreviewDialog(context, url, product.name),
                              child: Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border),
                                      image: DecorationImage(
                                        image: NetworkImage(url),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  if (isAdmin)
                                    Positioned(
                                      top: 2,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: () => _deleteImage(context, ref, product, url),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Brochures Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PDF Brochures (${product.brochures.length})',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isAdmin)
                          InkWell(
                            onTap: () => _uploadBrochure(context, ref, product),
                            child: const Row(
                              children: [
                                Icon(Icons.upload_file_outlined, size: 16, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text('Add Brochure', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (product.brochures.isEmpty)
                      const Text('No brochures uploaded yet.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary))
                    else
                      Column(
                        children: product.brochures.map((brochure) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.picture_as_pdf, size: 18, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    brochure.title,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                                  tooltip: 'View PDF (In-App)',
                                  onPressed: () => _viewBrochureInApp(context, brochure.url, brochure.title),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share_outlined, size: 18, color: AppColors.accent),
                                  tooltip: 'Share PDF File',
                                  onPressed: () => _shareBrochurePdfFile(context, brochure.url, brochure.title),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.success),
                                  tooltip: 'Download',
                                  onPressed: () => _downloadUrlFile(context, brochure.url, '${brochure.title.replaceAll(" ", "_")}.pdf'),
                                ),
                                if (isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteBrochure(context, ref, product, brochure),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: (isAdmin && !isViewOnly)
          ? FloatingActionButton.extended(
              onPressed: () => _showAddProductDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Product',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Product'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'e.g. Boom Barrier',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  hintText: 'e.g. Security',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                final supabase = ref.read(supabaseClientProvider);
                await supabase.from('products').insert({
                  'name': nameController.text.trim(),
                  'category': categoryController.text.trim(),
                  'base_specs': {
                    'quotation_fields': [],
                    'boq_required_fields': [],
                  },
                  'is_active': true,
                });

                ref.invalidate(productsProvider);
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Product added successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, WidgetRef ref, Product product) {
    final nameController = TextEditingController(text: product.name);
    final categoryController = TextEditingController(text: product.category);
    bool isActive = product.isActive;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Edit Product'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isActive,
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => isActive = val);
                        }
                      },
                    ),
                    const Text('Product is Active'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  final supabase = ref.read(supabaseClientProvider);
                  await supabase.from('products').update({
                    'name': nameController.text.trim(),
                    'category': categoryController.text.trim(),
                    'is_active': isActive,
                  }).eq('id', product.id);

                  ref.invalidate(productsProvider);
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product updated successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteProductDialog(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? '
          'This will remove it from the catalog but preserve historical pipeline records.',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final supabase = ref.read(supabaseClientProvider);
                await supabase.from('products').update({
                  'deleted_at': DateTime.now().toIso8601String(),
                }).eq('id', product.id);

                ref.invalidate(productsProvider);
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Product deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadImage(BuildContext context, WidgetRef ref, Product product) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading product photo...'), backgroundColor: AppColors.info),
    );

    try {
      final bytes = await image.readAsBytes();
      final supabase = ref.read(supabaseClientProvider);
      final filename = 'prod_${product.id}_${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage.from('product-images').uploadBinary(
        filename,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final publicUrl = supabase.storage.from('product-images').getPublicUrl(filename);

      final updatedImages = [...product.imageUrls, publicUrl];
      await supabase.from('products').update({'image_urls': updatedImages}).eq('id', product.id);
      ref.invalidate(productsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Product photo uploaded!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteImage(BuildContext context, WidgetRef ref, Product product, String targetUrl) async {
    final supabase = ref.read(supabaseClientProvider);
    final updatedImages = product.imageUrls.where((u) => u != targetUrl).toList();
    await supabase.from('products').update({'image_urls': updatedImages}).eq('id', product.id);
    ref.invalidate(productsProvider);
  }

  Future<void> _uploadBrochure(BuildContext context, WidgetRef ref, Product product) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isEmpty || files.first.path == null) return;
    final file = files.first;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading ${file.name}...'), backgroundColor: AppColors.info),
      );
    }

    try {
      final bytes = await File(file.path!).readAsBytes();
      final supabase = ref.read(supabaseClientProvider);
      final filename = 'brochure_${product.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await supabase.storage.from('product-brochures').uploadBinary(
        filename,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final publicUrl = supabase.storage.from('product-brochures').getPublicUrl(filename);

      final newBrochure = ProductBrochure(title: file.name.replaceAll('.pdf', ''), url: publicUrl);
      final updatedBrochures = [...product.brochures.map((b) => b.toJson()), newBrochure.toJson()];
      await supabase.from('products').update({'brochure_urls': updatedBrochures}).eq('id', product.id);
      ref.invalidate(productsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ PDF Brochure uploaded!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading brochure: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteBrochure(BuildContext context, WidgetRef ref, Product product, ProductBrochure targetBrochure) async {
    final supabase = ref.read(supabaseClientProvider);
    final updatedBrochures = product.brochures
        .where((b) => b.url != targetBrochure.url || b.title != targetBrochure.title)
        .map((b) => b.toJson())
        .toList();
    await supabase.from('products').update({'brochure_urls': updatedBrochures}).eq('id', product.id);
    ref.invalidate(productsProvider);
  }

  void _showImagePreviewDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Share.share(url, subject: '$title Photo');
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _downloadUrlFile(context, url, '${title.replaceAll(" ", "_")}_photo.jpg');
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadUrlFile(BuildContext context, String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading file...'), duration: Duration(seconds: 2)),
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!dir.existsSync()) {
            dir = await getExternalStorageDirectory();
          }
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        final file = File('${dir!.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (context.mounted) {
          await FileFolderHelper.askViewInFolder(
            context,
            fileName: fileName,
            locationName: 'Downloads',
            filePath: file.path,
            folderPath: dir.path,
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e. Opening via browser...'),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: 'Open / Share',
              textColor: Colors.white,
              onPressed: () => Share.share(url, subject: fileName),
            ),
          ),
        );
      }
    }
  }

  Future<void> _viewBrochureInApp(BuildContext context, String url, String title) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading PDF brochure...'), duration: Duration(seconds: 2)),
      );
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: response.bodyBytes,
              fileName: '$title.pdf',
            ),
          ),
        );
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _shareBrochurePdfFile(BuildContext context, String url, String title) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing PDF file for sharing...'), duration: Duration(seconds: 2)),
      );
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${title.replaceAll(" ", "_")}.pdf');
        await tempFile.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: 'Brochure for $title',
        );
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        Share.share(url, subject: title);
      }
    }
  }
}
