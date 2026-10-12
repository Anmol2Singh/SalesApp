// test/quotation_generator/qg_noc_eligibility_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/services/qg_noc_eligibility_service.dart';

void main() {
  group('QgNocEligibilityService Matrix Tests', () {
    const dealId = 'deal-101';
    const customerId = 'cust-202';

    final completedDeal = {
      'id': dealId,
      'status': 'completed',
      'customer_id': customerId,
      'created_at': '2026-05-01T10:00:00Z',
      'product_name': 'Boom Barrier',
    };

    final inProgressDeal = {
      'id': dealId,
      'status': 'in_progress',
      'customer_id': customerId,
      'created_at': '2026-05-01T10:00:00Z',
      'product_name': 'Boom Barrier',
    };

    final resolvedInstallation = {
      'id': 'inst-1',
      'customer_id': customerId,
      'status': 'resolved',
      'notes': 'Supporters: John\nDeal ID: $dealId',
      'created_at': '2026-05-02T10:00:00Z',
    };

    final closedInstallation = {
      'id': 'inst-2',
      'customer_id': customerId,
      'status': 'closed',
      'notes': 'Deal ID: $dealId',
      'created_at': '2026-05-02T10:00:00Z',
    };

    final inProgressInstallation = {
      'id': 'inst-3',
      'customer_id': customerId,
      'status': 'in_progress',
      'notes': 'Deal ID: $dealId',
      'created_at': '2026-05-02T10:00:00Z',
    };

    test('1. Completed deal + resolved installation -> Eligible', () {
      final res = QgNocEligibilityService.evaluateEligibility(
        deal: completedDeal,
        installations: [resolvedInstallation],
      );

      expect(res.isEligible, isTrue);
      expect(res.reasons, isEmpty);
      expect(res.matchedInstallation?['id'], equals('inst-1'));
    });

    test('2. Completed deal + closed installation -> Eligible', () {
      final res = QgNocEligibilityService.evaluateEligibility(
        deal: completedDeal,
        installations: [closedInstallation],
      );

      expect(res.isEligible, isTrue);
      expect(res.reasons, isEmpty);
      expect(res.matchedInstallation?['id'], equals('inst-2'));
    });

    test('3. Completed deal + in_progress installation -> Ineligible with reason', () {
      final res = QgNocEligibilityService.evaluateEligibility(
        deal: completedDeal,
        installations: [inProgressInstallation],
      );

      expect(res.isEligible, isFalse);
      expect(res.reasons, contains('Installation not completed'));
    });

    test('4. Completed deal + no installation -> Ineligible with reason', () {
      final res = QgNocEligibilityService.evaluateEligibility(
        deal: completedDeal,
        installations: [],
      );

      expect(res.isEligible, isFalse);
      expect(res.reasons, contains('Installation not completed'));
    });

    test('5. In-progress deal + resolved installation -> Ineligible (Deal incomplete)', () {
      final res = QgNocEligibilityService.evaluateEligibility(
        deal: inProgressDeal,
        installations: [resolvedInstallation],
      );

      expect(res.isEligible, isFalse);
      expect(res.reasons, contains('Deal is not 100% complete'));
      expect(res.reasons, isNot(contains('Installation not completed')));
    });

    test('6. In-progress deal + no installation -> Both reasons reported', () {
      final res = QgNocEligibilityService.evaluateEligibility(
        deal: inProgressDeal,
        installations: [],
      );

      expect(res.isEligible, isFalse);
      expect(res.reasons, contains('Deal is not 100% complete'));
      expect(res.reasons, contains('Installation not completed'));
    });

    test('7. Admin override enabled only when user is admin, deal is complete, and installation is missing', () {
      // Non-admin cannot override
      final nonAdminRes = QgNocEligibilityService.evaluateEligibility(
        deal: completedDeal,
        installations: [],
        isAdmin: false,
      );
      expect(nonAdminRes.canAdminOverride, isFalse);

      // Admin can override missing installation on completed deal
      final adminRes = QgNocEligibilityService.evaluateEligibility(
        deal: completedDeal,
        installations: [],
        isAdmin: true,
      );
      expect(adminRes.canAdminOverride, isTrue);

      // Admin CANNOT override if deal itself is incomplete
      final adminIncompleteDealRes = QgNocEligibilityService.evaluateEligibility(
        deal: inProgressDeal,
        installations: [],
        isAdmin: true,
      );
      expect(adminIncompleteDealRes.canAdminOverride, isFalse);
    });

    test('8. Fallback link matches customer_id and product_name on or after deal creation', () {
      final fallbackInst = {
        'id': 'inst-fallback',
        'customer_id': customerId,
        'product_name': 'Boom Barrier',
        'status': 'resolved',
        'notes': 'No explicit deal id',
        'created_at': '2026-05-03T10:00:00Z',
      };

      final res = QgNocEligibilityService.evaluateEligibility(
        deal: completedDeal,
        installations: [fallbackInst],
      );

      expect(res.isEligible, isTrue);
      expect(res.matchedInstallation?['id'], equals('inst-fallback'));
    });
  });
}
