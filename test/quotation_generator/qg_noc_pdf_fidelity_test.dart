// test/quotation_generator/qg_noc_pdf_fidelity_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/models/qg_noc_builder_state.dart';
import 'package:salesapp/features/quotation_generator/services/pdf_noc_builder.dart';

void main() {
  group('Milestone N3: NOC Template Fidelity Golden Test', () {
    test('Verifies generated template_exact PDF matches reference/NOC_Template.pdf >= 97%', () async {
      final templatePayload = QgNocPayload(
        companyName: 'INSIYA TRADING CORPORATION',
        companyAddress: 'Office no.807,finswell,behind Hyatt Hotel,\n Viman Nagar, Pune 411014',
        companyEmail: 'insiyaindia@gmail.com    info@insiyacorp.com',
        companyPhone: '+91 7588874019 & +91 9292922992',
        companyWebsite: 'www.insiyacorp.com',
        salutation: 'M/s',
        customerName: 'TURQUOISE PUNE',
        address: 'S.NO. 134 GROUND AND SIX FLOORS TURQUOISE PUNE, NAGAR ROAD Pune, \nMaharashtra  411014',
        productName: 'Boom Barrier',
        subject: 'No Objection Certificate for Installation & Commissioning of Boom Barrier.',
        date: DateTime(2026, 10, 10),
        equipmentLabel: 'Boom Barrier',
        equipmentLines: const [
          NocEquipmentLine(
            product: 'Boom Barrier',
            model: 'IZ-2001',
            quantity: 2,
            uom: 'Nos',
          ),
        ],
        workType: 'Boom Barrier Installation work',
        wiring: 'Done',
        testing: 'Done',
        remark: 'All Installation & Commissioning work Completed as per work order',
        confirmations: const [
          '1. The installation of the Boom Barrier is permitted at the above location.',
          '3. Necessary precautions has been.',
        ],
        closingSentence: 'This NOC is issued upon request for installation and operationBoom \nBarrier System.',
        wordingMode: NocWordingMode.templateExact,
      );

      // 1. Generate the PDF
      final pdfBytes = await PdfNocBuilder.buildNocPdf(templatePayload);
      expect(pdfBytes, isNotNull);

      // Save to scratch
      final outDir = Directory('scratch');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final outFile = File('scratch/noc_fidelity_test.pdf');
      outFile.writeAsBytesSync(pdfBytes);
      expect(outFile.existsSync(), isTrue);

      // 2. Invoke compare_noc_fidelity.py
      final result = Process.runSync('python', [
        'tools/quotation_generator/compare_noc_fidelity.py',
        'reference/NOC_Template.pdf',
        'scratch/noc_fidelity_test.pdf',
      ]);

      // ignore: avoid_print
      print(result.stdout);
      if (result.stderr.toString().isNotEmpty) {
        // ignore: avoid_print
        print('STDERR: ${result.stderr}');
      }

      expect(
        result.exitCode,
        equals(0),
        reason: 'NOC PDF fidelity comparison failed. Output: ${result.stdout}\nError: ${result.stderr}',
      );
    });
  });
}
