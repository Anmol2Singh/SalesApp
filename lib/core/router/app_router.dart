// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/customers/screens/customer_list_screen.dart';
import '../../features/customers/screens/customer_detail_screen.dart';
import '../../features/customers/screens/create_customer_screen.dart';
import '../../features/pipelines/screens/pipeline_list_screen.dart';
import '../../features/pipelines/screens/pipeline_detail_screen.dart';
import '../../features/quotation/screens/quotation_form_screen.dart';
import '../../features/quotation_generator/config/quotation_generator_flags.dart';
import '../../features/quotation_generator/ui/screens/quotation_history_screen.dart';
import '../../features/quotation_generator/ui/screens/quotation_form_screen.dart' show QuotationGeneratorFormScreen;
import '../../features/quotation_generator/ui/screens/noc_hub_screen.dart';
import '../../features/quotation_generator/ui/screens/noc_builder_screen.dart';
import '../../features/sales_order/screens/sales_order_form_screen.dart';
import '../../features/boq/screens/boq_form_screen.dart';
import '../../features/boq/screens/boq_dashboard_screen.dart';
import '../../features/admin/screens/manage_boq_items_screen.dart';
import '../../features/factory_order/screens/factory_order_screen.dart';
import '../../features/factory_order/screens/factory_queue_screen.dart';
import '../../features/purchase_order/screens/purchase_order_screen.dart';
import '../../features/purchase_order/screens/purchase_queue_screen.dart';
import '../../features/notifications/screens/notification_center_screen.dart';
import '../../features/dashboard/screens/admin_dashboard_screen.dart';
import '../../features/reports/screens/user_activity_report_screen.dart';
import '../../features/reports/screens/customer_report_screen.dart';
import '../../features/pdf_search/screens/search_pdf_screen.dart';
import '../../features/dashboard/screens/sales_dashboard_screen.dart';
import '../../features/admin/screens/admin_panel_screen.dart';
import '../../features/admin/screens/product_catalog_screen.dart';
import '../../features/admin/screens/inventory_screen.dart';
import '../../features/admin/screens/pdf_template_screen.dart';
import '../../features/admin/screens/add_old_customer_screen.dart';
import '../../features/admin/screens/pdf_list_hub_screen.dart';
import '../../features/amc/screens/amc_list_screen.dart';
import '../../features/amc/screens/amc_detail_screen.dart';
import '../../features/amc/screens/amc_setup_form_screen.dart';
import '../../features/daily_tasks/screens/daily_tasks_screen.dart';
import '../../features/amc/screens/service_visit_form_screen.dart';
import '../../features/amc/screens/warranty_card_screen.dart';
import '../../features/customer_app/screens/customer_dashboard_screen.dart';
import '../../features/complaints/screens/coordinator_dashboard_screen.dart';
import '../../features/complaints/screens/book_complaint_screen.dart';
import '../../features/complaints/screens/technician_dashboard_screen.dart';
import '../../features/complaints/screens/technician_tasks_screen.dart';
import '../../features/complaints/screens/assign_technician_screen.dart';
import '../../features/complaints/screens/service_history_screen.dart';
import '../../features/complaints/screens/complaint_details_screen.dart';
import '../../features/complaints/screens/complaints_list_screen.dart';
import '../../features/complaints/screens/technicians_tab_screen.dart';
import '../../features/complaints/screens/error_codes_configuration_screen.dart';
import '../../features/complaints/screens/edit_complaint_screen.dart';
import '../../features/installations/screens/installation_dashboard_screen.dart';
import '../../features/installations/screens/installations_list_screen.dart';
import '../../features/installations/screens/installation_history_screen.dart';
import '../../features/installations/screens/assign_technician_screen.dart';
import '../../features/installations/screens/book_installation_screen.dart';
import '../../features/installations/screens/installation_details_screen.dart';
import '../../features/crm/widgets/crm_shell.dart';
import '../../features/crm/screens/crm_dashboard_screen.dart';
import '../../features/crm/screens/prospects_list_screen.dart';
import '../../features/crm/screens/leads_list_screen.dart';
import '../../features/crm/screens/lead_detail_screen.dart';
import '../../features/crm/screens/crm_customers_list_screen.dart';
import '../../features/crm/screens/crm_customer_detail_screen.dart';
import '../../features/crm/screens/prospect_detail_screen.dart';
import '../models/user_role.dart';
import '../widgets/app_shell.dart';
import '../../features/project_manager/presentation/screens/pm_dashboard_screen.dart';
import '../../features/project_manager/presentation/screens/pm_project_detail_screen.dart';
import '../../features/project_manager/presentation/screens/pm_project_form_screen.dart';
import '../../features/project_manager/presentation/screens/pm_filter_screen.dart';
import '../../features/dashboard/screens/product_interests_screen.dart';
import '../../features/project_manager/presentation/screens/pm_quick_call_remark_screen.dart';
import '../../features/project_manager/presentation/screens/pm_daily_transactions_screen.dart';

// Customer app imports
import '../../features/customer_app/features/auth/screens/otp_screen.dart';
import '../../features/customer_app/features/dashboard/screens/main_dashboard.dart';
import '../../features/customer_app/features/bookings/screens/bookings_list_screen.dart';
import '../../features/customer_app/features/tracking/screens/live_tracking_screen.dart';
import '../../features/customer_app/features/invoices/screens/invoice_list_screen.dart';
import '../../features/customer_app/features/support/screens/support_screen.dart';
import '../../features/customer_app/features/profile/screens/profile_screen.dart';
import '../../features/customer_app/features/services/screens/amc_avail_screen.dart';
import '../../features/customer_app/features/store/screens/request_product_screen.dart';
import '../../features/customer_app/features/product/screens/product_detail_screen.dart';
import '../../features/customer_app/features/service_request/screens/service_booking_flow.dart';
import '../widgets/customer_app_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();


// Route names
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String salesDashboard = '/sales/dashboard';
  static const String inventory = '/inventory';
  static const String customers = '/customers';
  static const String customerDetail = '/customers/:id';
  static const String createCustomer = '/customers/new';
  static const String pipelines = '/pipelines';
  static const String pipelineDetail = '/pipelines/:id';
  static const String quotationForm = '/pipelines/:id/quotation';
  static const String salesOrderForm = '/pipelines/:id/sales-order';
  static const String boqForm = '/pipelines/:id/boq';
  static const String factoryOrderForm = '/pipelines/:id/factory-order';
  static const String factoryQueue = '/factory/queue';
  static const String purchaseOrderForm = '/pipelines/:id/purchase-order';
  static const String purchaseQueue = '/purchase/queue';
  static const String notifications = '/notifications';
  static const String userManagement = '/admin/users';
  static const String productCatalog = '/admin/products';
  static const String pdfTemplates = '/admin/pdf-templates';
  static const String addOldCustomer = '/admin/add-old-customer';
  static const String amcList = '/amc';
  static const String amcDetail = '/amc/details/:id';
  static const String amcSetup = '/amc/setup';
  static const String complaintsDashboard = '/complaints/dashboard';
  static const String technicianDashboard = '/technician/dashboard';
  static const String technicianTasks = '/technician/tasks';
  static const String bookComplaint = '/complaints/book';
  static const String assignTechnician = '/complaints/assign';
  static const String serviceHistory = '/complaints/history';
  static const String complaintsList = '/complaints';
  static const String installationsDashboard = '/installations/dashboard';
  static const String installationsList = '/installations';
  static const String bookInstallation = '/installations/book';
  static const String assignInstallation = '/installations/assign';
  static const String installationHistory = '/installations/history';
  static const String searchPdf = '/search-pdf';
  static const String pdfList = '/admin/pdf-list';
  static const String boqDashboard = '/boq/dashboard';
  static const String manageBoqItems = '/boq/manage-items';
  static const String dailyTasks = '/daily-tasks';
  static const String heatPumpQuotationHub = '/heat-pump-quotations';
  static const String heatPumpQuotationCreate = '/heat-pump-quotations/new';
  static const String nocHub = '/qg/noc';
  static const String nocBuilder = '/qg/noc/builder';
  static const String projectManager = '/pm';
  static const String pmProjectNew = '/pm/projects/new';
  static const String pmProjectDetail = '/pm/projects/:id';
  static const String pmProjectEdit = '/pm/projects/:id/edit';
  static const String pmCallRemark = '/pm/projects/:id/call-remark';
  static const String pmFilter = '/pm/filter';
  static const String pmDailyTransactions = '/pm/daily-transactions';
  static const String productInterests = '/product-interests';
  static const String userActivityReport = '/reports/activity';
  static const String customerReport = '/reports/customer';
  static const String products = '/products';
}

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen<AsyncValue<Profile?>>(authStateProvider, (prev, next) {
      if (prev?.value != next.value) {
        notifyListeners();
      }
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authState = ref.read(authStateProvider);

      // Customer app routes — guarded only by the customer auth (phone OTP).
      // Do NOT apply office-login redirect here.
      final isCustomerRoute = location.startsWith('/customer') ||
          location == '/bookings' ||
          location == '/track' ||
          location == '/invoices' ||
          location == '/support' ||
          location == '/profile' ||
          location.startsWith('/product') ||
          location == '/amc_avail' ||
          location == '/request_product' ||
          location.startsWith('/service-booking');

      if (isCustomerRoute) return null;

      if (authState.isLoading && authState.value == null) return null;

      final isLoggedIn = authState.value != null;
      final isOnAuth = location == AppRoutes.login ||
          location == AppRoutes.splash ||
          location == '/otp';

      if (!isLoggedIn && !isOnAuth) {
        return AppRoutes.login;
      }

      if (isLoggedIn) {
        final profile = authState.value;
        if (profile != null) {
          if (isOnAuth) {
            return _getRoleHome(profile.primaryRole);
          }
          // Guard pure CRM Staff (without sales or admin roles) from accessing customer screens
          if (profile.roles.contains(UserRole.crmStaff) &&
              !profile.roles.any((r) => r.isSalesOrAdmin)) {
            if (location == AppRoutes.customers ||
                location.startsWith('/customers') ||
                location.startsWith('/crm/customers')) {
              return '/crm/dashboard';
            }
          }

          // Guard Quotation Generator (strictly admin only per requirement)
          if (location == AppRoutes.heatPumpQuotationHub ||
              location == AppRoutes.heatPumpQuotationCreate ||
              location.startsWith('/quotation-generator')) {
            if (!profile.roles.contains(UserRole.admin)) {
              return _getRoleHome(profile.primaryRole);
            }
          }

          // Guard Accounts role: access to Project Manager module only
          if (profile.roles.contains(UserRole.accounts) &&
              !profile.roles.contains(UserRole.admin) &&
              !profile.roles.contains(UserRole.manager)) {
            if (!location.startsWith('/pm')) {
              return AppRoutes.projectManager;
            }
          }

          // Guard Project Manager module: strictly admin, manager, or accounts
          if (location.startsWith('/pm')) {
            final canAccess = profile.roles.any((r) => r.canAccessProjectManager);
            if (!canAccess) {
              return _getRoleHome(profile.primaryRole);
            }
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final phone = extra?['phone'] ?? '';
          return OTPScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final productId = state.pathParameters['id'] ?? '';
          return ProductDetailScreen(productId: productId);
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return CustomerAppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/customer/dashboard',
            builder: (context, state) => const MainDashboard(),
          ),
          GoRoute(
            path: '/bookings',
            builder: (context, state) => const BookingsListScreen(),
          ),
          GoRoute(
            path: '/track',
            builder: (context, state) => const LiveTrackingScreen(),
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoiceListScreen(),
          ),
          GoRoute(
            path: '/support',
            builder: (context, state) => const SupportScreen(),
          ),
          GoRoute(
            path: '/amc_avail',
            builder: (context, state) => AmcAvailScreen(
              initialProductId: state.uri.queryParameters['productId'],
              mode: state.uri.queryParameters['mode'],
            ),
          ),
          GoRoute(
            path: '/request_product',
            builder: (context, state) => const RequestProductScreen(),
          ),
          GoRoute(
            path: '/service-booking',
            builder: (context, state) {
              final prodId = state.uri.queryParameters['productId'];
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: ServiceBookingFlow(preselectedProductId: prodId),
              );
            },
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentRoute: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.salesDashboard,
            builder: (context, state) => const SalesDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.adminDashboard,
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => const CustomerListScreen(),
          ),
          GoRoute(
            path: AppRoutes.pipelines,
            builder: (context, state) => const PipelineListScreen(),
          ),
          GoRoute(
            path: AppRoutes.factoryQueue,
            builder: (context, state) => FactoryQueueScreen(),
          ),
          GoRoute(
            path: AppRoutes.purchaseQueue,
            builder: (context, state) => const PurchaseQueueScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationCenterScreen(),
          ),
          GoRoute(
            path: AppRoutes.boqDashboard,
            builder: (context, state) => const BoqDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.manageBoqItems,
            builder: (context, state) => Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text(
                  'Manage BOQ Items',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFF1E1B4B),
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.boqDashboard);
                    }
                  },
                ),
              ),
              body: const ManageBoqItemsScreen(isEmbedded: true),
            ),
          ),
          GoRoute(
            path: AppRoutes.userManagement,
            builder: (context, state) => const AdminPanelScreen(),
          ),
          GoRoute(
            path: AppRoutes.addOldCustomer,
            builder: (context, state) => const AddOldCustomerScreen(),
          ),
          GoRoute(
            path: AppRoutes.inventory,
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.searchPdf,
            builder: (context, state) => const SearchPdfScreen(),
          ),
          GoRoute(
            path: AppRoutes.pdfList,
            builder: (context, state) => const PdfListHubScreen(),
          ),
          GoRoute(
            path: AppRoutes.amcList,
            builder: (context, state) => const AmcListScreen(),
          ),
          GoRoute(
            path: AppRoutes.dailyTasks,
            builder: (context, state) => const DailyTasksScreen(),
          ),
          GoRoute(
            path: AppRoutes.heatPumpQuotationHub,
            builder: (context, state) => const QuotationHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.projectManager,
            builder: (context, state) => const PmDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.pmDailyTransactions,
            builder: (context, state) => const PmDailyTransactionsScreen(),
          ),
          ShellRoute(
            builder: (context, state, child) {
              return CrmShell(
                currentRoute: state.uri.path,
                child: child,
              );
            },
            routes: [
              GoRoute(
                path: '/crm/dashboard',
                builder: (context, state) => const CrmDashboardScreen(),
              ),
              GoRoute(
                path: '/crm/prospects',
                builder: (context, state) => const ProspectsListScreen(),
              ),
              GoRoute(
                path: '/crm/prospects/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return ProspectDetailScreen(id: id);
                },
              ),
              GoRoute(
                path: '/crm/leads',
                builder: (context, state) => const LeadsListScreen(),
              ),
              GoRoute(
                path: '/crm/leads/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return LeadDetailScreen(id: id);
                },
              ),
              GoRoute(
                path: '/crm/customers',
                builder: (context, state) => const CrmCustomersListScreen(),
              ),
              GoRoute(
                path: '/crm/customers/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return CrmCustomerDetailScreen(leadId: id);
                },
              ),
            ],
          ),

          GoRoute(
            path: AppRoutes.complaintsDashboard,
            builder: (context, state) => const CoordinatorDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.technicianDashboard,
            builder: (context, state) => const TechnicianDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.technicianTasks,
            builder: (context, state) {
              final tabParam = state.uri.queryParameters['tab'];
              final initialTab = (tabParam == 'installations' || tabParam == '1') ? 1 : 0;
              return TechnicianTasksScreen(initialTab: initialTab);
            },
          ),
          GoRoute(
            path: AppRoutes.bookComplaint,
            builder: (context, state) => const BookComplaintScreen(),
          ),
          GoRoute(
            path: AppRoutes.assignTechnician,
            builder: (context, state) => const AssignTechnicianScreen(),
          ),
          GoRoute(
            path: AppRoutes.serviceHistory,
            builder: (context, state) => const ServiceHistoryScreen(),
          ),
          GoRoute(
            path: '/complaints/technicians',
            builder: (context, state) => const TechniciansTabScreen(),
          ),
          GoRoute(
            path: AppRoutes.complaintsList,
            builder: (context, state) => const ComplaintsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.installationsDashboard,
            builder: (context, state) => const InstallationDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.installationsList,
            builder: (context, state) => const InstallationsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.assignInstallation,
            builder: (context, state) => const AssignInstallationTechnicianScreen(),
          ),
          GoRoute(
            path: AppRoutes.installationHistory,
            builder: (context, state) => const InstallationHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.productInterests,
            builder: (context, state) => const ProductInterestsScreen(),
          ),
          GoRoute(
            path: '/reports/activity',
            builder: (context, state) => const UserActivityReportScreen(),
          ),
          GoRoute(
            path: '/reports/customer',
            builder: (context, state) => const CustomerReportScreen(),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductCatalogScreen(isEmbedded: false),
          ),
        ],
      ),
      // Detail/Form views (Full screen)
      GoRoute(
        path: AppRoutes.pmProjectNew,
        builder: (context, state) {
          final isPurchase = state.uri.queryParameters['mode'] == 'purchase';
          return PmProjectFormScreen(isPurchase: isPurchase);
        },
      ),
      GoRoute(
        path: AppRoutes.pmProjectDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final isPurchase = state.uri.queryParameters['mode'] == 'purchase';
          return PmProjectDetailScreen(id: id, isPurchase: isPurchase);
        },
      ),
      GoRoute(
        path: AppRoutes.pmProjectEdit,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final isPurchase = state.uri.queryParameters['mode'] == 'purchase';
          return PmProjectFormScreen(editId: id, isPurchase: isPurchase);
        },
      ),
      GoRoute(
        path: AppRoutes.pmCallRemark,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final isPurchase = state.uri.queryParameters['mode'] == 'purchase';
          return PmQuickCallRemarkScreen(id: id, isPurchase: isPurchase);
        },
      ),
      GoRoute(
        path: AppRoutes.pmFilter,
        builder: (context, state) => const PmFilterScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookInstallation,
        builder: (context, state) => const BookInstallationScreen(),
      ),
      GoRoute(
        path: '/installations/details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return InstallationDetailsScreen(installationId: id);
        },
      ),
      GoRoute(
        path: '/complaints/details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ComplaintDetailsScreen(complaintId: id);
        },
      ),
      GoRoute(
        path: '/complaints/error-codes',
        builder: (context, state) => const ErrorCodesConfigurationScreen(),
      ),
      GoRoute(
        path: '/complaints/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditComplaintScreen(complaintId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.createCustomer,
        builder: (context, state) => const CreateCustomerScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomerDetailScreen(customerId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.amcDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AmcDetailScreen(amcId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.pipelineDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PipelineDetailScreen(pipelineId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.quotationForm,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return QuotationFormScreen(pipelineId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.heatPumpQuotationCreate,
        builder: (context, state) => kQgStandaloneCreateEnabled
            ? const QuotationGeneratorFormScreen()
            : const QuotationHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.nocHub,
        builder: (context, state) => const NocHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.nocBuilder,
        builder: (context, state) {
          final dealId = state.uri.queryParameters['dealId'];
          final quotationId = state.uri.queryParameters['quotationId'];
          final documentId = state.uri.queryParameters['documentId'];
          final newVersion = state.uri.queryParameters['newVersion'] == 'true';
          return NocBuilderScreen(
            dealId: dealId,
            quotationId: quotationId,
            documentId: documentId,
            newVersion: newVersion,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.salesOrderForm,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SalesOrderFormScreen(pipelineId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.boqForm,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BoqFormScreen(pipelineId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.factoryOrderForm,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FactoryOrderScreen(pipelineId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.purchaseOrderForm,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PurchaseOrderScreen(pipelineId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.productCatalog,
        builder: (context, state) => const ProductCatalogScreen(),
      ),
      GoRoute(
        path: AppRoutes.pdfTemplates,
        builder: (context, state) => const PdfTemplateScreen(),
      ),
      GoRoute(
        path: AppRoutes.amcSetup,
        builder: (context, state) {
          final amcId = state.uri.queryParameters['amcId'];
          final customerId = state.uri.queryParameters['customerId'];
          final productId = state.uri.queryParameters['productId'];
          final pipelineId = state.uri.queryParameters['pipelineId'];
          return AmcSetupFormScreen(
            amcId: amcId,
            customerId: customerId,
            productId: productId,
            pipelineId: pipelineId,
          );
        },
      ),
      GoRoute(
        path: '/service-visit/:customerId',
        builder: (context, state) {
          final customerId = state.pathParameters['customerId']!;
          final pipelineId = state.uri.queryParameters['pipelineId'];
          final contractId = state.uri.queryParameters['contractId'];
          return ServiceVisitFormScreen(customerId: customerId, pipelineId: pipelineId, contractId: contractId);
        },
      ),
      GoRoute(
        path: '/warranty/:id',
        builder: (context, state) {
          final pipelineId = state.pathParameters['id']!;
          final customerId = state.uri.queryParameters['customerId'] ?? '';
          return WarrantyCardScreen(pipelineId: pipelineId, customerId: customerId);
        },
      ),
      GoRoute(
        path: '/customer/dashboard',
        builder: (context, state) => const CustomerDashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Page not found: ${state.error?.message ?? 'Unknown error'}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

String getRoleHome(UserRole role) {
  switch (role) {
    case UserRole.admin:
    case UserRole.manager:
      return AppRoutes.adminDashboard;
    case UserRole.sales:
    case UserRole.salesHead:
      return AppRoutes.salesDashboard;
    case UserRole.factory:
    case UserRole.purchase:
    case UserRole.boq:
      return AppRoutes.boqDashboard;
    case UserRole.serviceHead:
      return AppRoutes.complaintsDashboard;
    case UserRole.installation:
      return AppRoutes.installationsDashboard;
    case UserRole.technician:
      return AppRoutes.technicianDashboard;
    case UserRole.customer:
      return '/customer/dashboard';
    case UserRole.crmStaff:
      return '/crm/dashboard';
    case UserRole.accounts:
      return AppRoutes.projectManager;
  }
}

String _getRoleHome(UserRole role) => getRoleHome(role);
