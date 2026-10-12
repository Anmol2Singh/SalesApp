// test/quotation_generator/quotation_isolation_source_scan_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Isolation Rule 3 Source-Scan Test', () {
    test('Verifies quotation_generator module contains NO writes to legacy tables or buckets', () {
      final moduleDir = Directory('lib/features/quotation_generator');
      expect(moduleDir.existsSync(), isTrue, reason: 'Module directory must exist');

      final dartFiles = moduleDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      expect(dartFiles, isNotEmpty);

      final legacyTables = [
        'quotations',
        'pdf_templates',
        'sales_pipelines',
        'customers',
        'profiles',
        'products',
        'inventory_items',
        'supplementary_items',
        'installations',
        'sales_orders',
      ];

      final legacyBuckets = [
        'company-assets',
        'product-images',
        'pdfs',
      ];

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        
        // Strip comments to avoid false positives in explanatory docs
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//') || line.startsWith('/*') || line.startsWith('*')) {
            continue;
          }

          // 1. Check for table write operations (.insert, .update, .upsert, .delete)
          // on any legacy table or table not prefixed with qg_
          for (final table in legacyTables) {
            final fromRegex = RegExp(r"\.from\(['" + table + r"']\)");
            if (fromRegex.hasMatch(line)) {
              // Check if subsequent lines or same line performs write
              final context = lines.sublist(i, (i + 5).clamp(0, lines.length)).join(' ');
              if (context.contains('.insert(') ||
                  context.contains('.update(') ||
                  context.contains('.upsert(') ||
                  context.contains('.delete(')) {
                violations.add(
                  '${file.path}:${i + 1} Unsafe write detected targeting core table "$table": "$line"',
                );
              }
            }
          }

          // 2. Check for storage bucket access to legacy buckets
          for (final bucket in legacyBuckets) {
            if (line.contains("storage.from('$bucket')") ||
                line.contains('storage.from("$bucket")')) {
              violations.add(
                '${file.path}:${i + 1} Storage access detected targeting legacy bucket "$bucket": "$line"',
              );
            }
          }

          // 3. Check for RPC calls: all RPCs in module must be prefixed with qg_
          final rpcRegex = RegExp(r"""\.rpc\(['"]([a-zA-Z0-9_]+)['"]""");
          final rpcMatch = rpcRegex.firstMatch(line);
          if (rpcMatch != null) {
            final rpcName = rpcMatch.group(1)!;
            if (!rpcName.startsWith('qg_')) {
              violations.add(
                '${file.path}:${i + 1} Non-qg RPC call detected "$rpcName": "$line"',
              );
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        fail('Source scan detected ${violations.length} isolation violations:\n${violations.join('\n')}');
      }
    });
  });
}
