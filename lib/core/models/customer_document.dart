// lib/core/models/customer_document.dart

class CustomerDocument {
  final String id;
  final String customerId;
  final String title;
  final String fileUrl;
  final String filePath;
  final String fileName;
  final String fileType; // 'pdf' or 'image'
  final int fileSize;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerDocument({
    required this.id,
    required this.customerId,
    required this.title,
    required this.fileUrl,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPdf => fileType.toLowerCase() == 'pdf' || fileName.toLowerCase().endsWith('.pdf');
  bool get isImage =>
      fileType.toLowerCase() == 'image' ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.webp');

  factory CustomerDocument.fromJson(Map<String, dynamic> json) {
    return CustomerDocument(
      id: json['id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Document',
      fileUrl: json['file_url'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      fileName: json['file_name'] as String? ?? 'document',
      fileType: json['file_type'] as String? ?? 'pdf',
      fileSize: (json['file_size'] as num? ?? 0).toInt(),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'title': title,
        'file_url': fileUrl,
        'file_path': filePath,
        'file_name': fileName,
        'file_type': fileType,
        'file_size': fileSize,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
