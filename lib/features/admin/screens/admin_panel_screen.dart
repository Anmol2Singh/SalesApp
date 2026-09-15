// lib/features/admin/screens/admin_panel_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import 'user_management_screen.dart';
import '../../complaints/screens/technicians_tab_screen.dart';
import 'product_catalog_screen.dart';
import 'pdf_template_screen.dart';
import 'manage_boq_items_screen.dart';
import 'company_helpline_screen.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.adminDashboard),
          ),
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          title: const Text(
            'Admin Panel',
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: Container(
              color: AppColors.surface,
              width: double.infinity,
              child: const TabBar(
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Staff Users', icon: Icon(Icons.people_outline)),
                  Tab(text: 'Technicians', icon: Icon(Icons.engineering_outlined)),
                  Tab(text: 'Product Catalog', icon: Icon(Icons.inventory_2_outlined)),
                  Tab(text: 'PDF Templates', icon: Icon(Icons.picture_as_pdf_outlined)),
                  Tab(text: 'Manage BOQ Items', icon: Icon(Icons.format_list_bulleted_outlined)),
                  Tab(text: 'Company Helpline', icon: Icon(Icons.support_agent_outlined)),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            UserManagementScreen(isEmbedded: true),
            TechniciansTabScreen(isEmbedded: true),
            ProductCatalogScreen(isEmbedded: true),
            PdfTemplateScreen(isEmbedded: true),
            ManageBoqItemsScreen(isEmbedded: true),
            CompanyHelplineScreen(isEmbedded: true),
          ],
        ),
      ),
    );
  }
}
