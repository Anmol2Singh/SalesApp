// lib/features/auth/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/user_role.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Offline / slow DNS timeout safety fallback (ensures splash never hangs indefinitely)
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && !_navigationStarted) {
        _navigationStarted = true;
        final currentProfile = ref.read(currentProfileProvider);
        if (currentProfile != null) {
          context.go(_getRoleHome(currentProfile.primaryRole));
        } else {
          context.go(AppRoutes.login);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    if (!_navigationStarted) {
      authState.when(
        data: (profile) {
          if (profile != null) {
            _navigationStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.go(_getRoleHome(profile.primaryRole));
              }
            });
          } else {
            _navigationStarted = true;
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                context.go(AppRoutes.login);
              }
            });
          }
        },
        loading: () {},
        error: (_, __) {
          _navigationStarted = true;
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              context.go(AppRoutes.login);
            }
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'IZYHEAT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SALES MANAGEMENT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 60),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accent.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getRoleHome(UserRole role) {
    switch (role) {
      case UserRole.admin:
      case UserRole.manager:
        return AppRoutes.adminDashboard;
      case UserRole.sales:
      case UserRole.salesHead:
      case UserRole.factory:
      case UserRole.purchase:
      case UserRole.boq:
        return AppRoutes.salesDashboard;
      case UserRole.serviceHead:
        return AppRoutes.complaintsDashboard;
      case UserRole.technician:
        return AppRoutes.technicianDashboard;
      case UserRole.customer:
        return '/customer/dashboard';
      case UserRole.crmStaff:
        return '/crm/dashboard';
    }
  }
}
