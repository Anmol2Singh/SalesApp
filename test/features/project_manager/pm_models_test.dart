import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/project_manager/data/models/pm_project.dart';
import 'package:salesapp/features/project_manager/data/models/pm_purchase.dart';
import 'package:salesapp/features/project_manager/data/models/pm_ledger_entry.dart';
import 'package:salesapp/features/project_manager/data/models/pm_payment_term.dart';
import 'package:salesapp/features/project_manager/data/models/pm_checklist_item.dart';
import 'package:salesapp/features/project_manager/data/models/pm_daily_transaction.dart';
import 'package:salesapp/features/project_manager/presentation/theme/pm_tokens.dart';

void main() {
  group('PmProject Model Tests', () {
    test('fromJson and balance calculation work accurately', () {
      final json = {
        'id': 'prj-101',
        'id_no': 42,
        'customer_id': 'cust-001',
        'pipeline_id': 'pipe-001',
        'order_type': 'Heat Pump',
        'site_name': 'Hotel Sunshine Rooftop',
        'address': 'MG Road, Pune',
        'hp_type': '5 HP Commercial',
        'hp_qty': 2,
        'tank_type': '1000L Insulated',
        'tank_qty': 2,
        'gl': 2000,
        'sales_m_value': 10000.0,
        'm_outward_value': 2000.0,
        'm_balance': 8000.0,
        'order_value': 150000.0,
        'extra_work_value': 15000.0,
        'payment_received': 65000.0,
        'work_remark': 'Plumbing completed',
        'salesman_name': 'Rahul Sharma',
        'company_id': 'insiya-solar',
        'customers': {
          'id': 'cust-001',
          'company_name': 'Sunshine Hospitality Pvt Ltd',
          'phone': '9876543210',
          'email': 'sunshine@example.com',
          'address': 'MG Road, Pune',
          'created_at': DateTime.now().toIso8601String(),
        },
      };

      final project = PmProject.fromJson(json);

      expect(project.id, 'prj-101');
      expect(project.idNo, 42);
      expect(project.customerId, 'cust-001');
      expect(project.orderType, 'Heat Pump');
      expect(project.siteName, 'Hotel Sunshine Rooftop');
      expect(project.hpQty, 2);
      expect(project.gl, 2000);
      expect(project.orderValue, 150000.0);
      expect(project.extraWorkValue, 15000.0);
      expect(project.paymentReceived, 65000.0);

      // (order_value + extra_work_value) - payment_received
      // (150000 + 15000) - 65000 = 100000
      expect(project.balance, 100000.0);
      expect(project.partyPrintName, 'Sunshine Hospitality Pvt Ltd');
      expect(project.mobileNumber, '9876543210');
      expect(project.firmName, 'Sunshine Hospitality Pvt Ltd');

      // Check toJson
      final exportedJson = project.toJson();
      expect(exportedJson['id_no'], 42);
      expect(exportedJson['site_name'], 'Hotel Sunshine Rooftop');
      expect(exportedJson['customer_id'], 'cust-001');
    });

    test('balance handles zero and negative correctly', () {
      final project = PmProject(
        id: 'prj-1',
        idNo: 1,
        customerId: 'cust-1',
        orderType: 'Solar',
        siteName: 'Site 1',
        orderValue: 50000,
        extraWorkValue: 0,
        paymentReceived: 50000,
        createdAt: DateTime.now(),
      );

      expect(project.balance, 0.0);

      final overpaid = project.copyWith(paymentReceived: 55000);
      expect(overpaid.balance, -5000.0);
    });
  });

  group('PmPurchase Model Tests', () {
    test('fromJson and balance calculation work accurately', () {
      final json = {
        'id': 'pur-01',
        'id_no': 5,
        'order_type': 'Raw Material',
        'site_name': 'Apex Copper Suppliers',
        'party_print_name': 'Apex Metals & Pipes',
        'mobile_number': '9123456789',
        'address': 'Industrial Area, Mumbai',
        'firm_name': 'Apex Corp',
        'quotation_value': 80000.0,
        'payment_paid': 30000.0,
        'balance': 50000.0,
        'company_id': 'insiya-solar',
      };

      final purchase = PmPurchase.fromJson(json);

      expect(purchase.id, 'pur-01');
      expect(purchase.idNo, 5);
      expect(purchase.siteName, 'Apex Copper Suppliers');
      expect(purchase.quotationValue, 80000.0);
      expect(purchase.paymentPaid, 30000.0);
      expect(purchase.balance, 50000.0);

      final exported = purchase.toJson();
      expect(exported['quotation_value'], 80000.0);
      expect(exported['party_print_name'], 'Apex Metals & Pipes');
    });
  });

  group('PmLedgerEntry Model Tests', () {
    test('calculates net debit and credit correctly', () {
      final entry = PmLedgerEntry(
        id: 'led-1',
        projectId: 'prj-101',
        srNo: 1,
        date: DateTime.parse('2026-03-15'),
        orderValue: 120000,
        extraWorkValue: 5000,
        paymentReceived: 40000,
        particulars: 'Initial booking advance',
        createdAt: DateTime.now(),
      );

      expect(entry.orderValue, 120000.0);
      expect(entry.extraWorkValue, 5000.0);
      expect(entry.paymentReceived, 40000.0);
      expect(entry.orderValue + entry.extraWorkValue - entry.paymentReceived, 85000.0);
    });
  });

  group('PmDailyTransaction Model Tests', () {
    test('maps entry natures and flows accurately', () {
      final json = {
        'id': 'dtx-1',
        'company_id': 'insiya-solar',
        'sr_no': 1,
        'date': '2026-04-10',
        'firm_name': 'Insiya Projects',
        'party_name': 'Ramesh Patel',
        'payment_mode': 'Cheque',
        'transaction_name': 'Advance Material',
        'entry_nature': 'Purchase',
        'type': 'debit',
        'debit_amount': 25000.0,
        'credit_amount': 0.0,
        'remark': 'Cheque #401292',
      };

      final tx = PmDailyTransaction.fromJson(json);

      expect(tx.entryNature, PmEntryNature.purchase);
      expect(tx.type, PmTransactionFlow.debit);
      expect(tx.debitAmount, 25000.0);
      expect(tx.creditAmount, 0.0);

      final exported = tx.toJson();
      expect(exported['entry_nature'], 'Purchase');
      expect(exported['type'], 'debit');
    });
  });

  group('PmPaymentTerm & Technical Checklist Tests', () {
    test('PaymentTerm pending amount calculation', () {
      final term = PmPaymentTerm(
        id: 'term-1',
        projectId: 'prj-1',
        paymentTerm: '50% on Delivery',
        termPercentage: 50,
        amount: 75000,
        receivedAmount: 25000,
        pendingAmount: 50000,
        createdAt: DateTime.now(),
      );

      expect(term.pendingAmount, 50000.0);
      expect(term.termPercentage, 50);
    });

    test('ChecklistItem dispatch balance calculation', () {
      final item = PmChecklistItem(
        id: 'chk-1',
        projectId: 'prj-1',
        srNo: 1,
        itemName: 'Heat Pump 5HP Outdoor Unit',
        reqQty: 2,
        dispatchQty: 1,
        installedQty: 1,
        dispatchBalanceQty: 1,
        createdAt: DateTime.now(),
      );

      expect(item.dispatchBalanceQty, 1);
      expect(item.reqQty, 2);
    });
  });

  group('PmTokens Design Tokens Tests', () {
    test('Resolves light and dark themes properly', () {
      final light = PmTokens.light();
      final dark = PmTokens.dark();

      expect(light.background, const Color(0xFFF0FDF9));
      expect(dark.background, const Color(0xFF0A0F1D));

      expect(light.primary, const Color(0xFF005CE6));
      expect(dark.primary, const Color(0xFF3B82F6));
      expect(light.destructive, const Color(0xFFEF4444));
    });
  });
}
