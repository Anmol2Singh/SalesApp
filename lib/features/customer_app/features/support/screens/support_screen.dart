import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:salesapp/core/providers/supabase_provider.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';

final companyContactProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  String name = 'Insiya Solar Industry';
  String address = 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014';
  String phone = '+91 9292922992';
  String whatsapp = '+91 9292922992';
  String email = 'insiyasolarindustry@gmail.com';
  String hours = 'Mon - Sat: 10:00 AM - 6:00 PM';
  String gstin = '27CFTPS5292A1ZY';

  // 1. Try local persistent storage (Company Helpline settings saved by admin)
  try {
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('company_helpline_settings');
    if (localJson != null && localJson.isNotEmpty) {
      final map = jsonDecode(localJson) as Map<String, dynamic>;
      if (map['company_name'] != null && map['company_name'].toString().isNotEmpty) name = map['company_name'].toString();
      if (map['address'] != null && map['address'].toString().isNotEmpty) address = map['address'].toString();
      if (map['phone'] != null && map['phone'].toString().isNotEmpty) phone = map['phone'].toString();
      if (map['whatsapp'] != null && map['whatsapp'].toString().isNotEmpty) whatsapp = map['whatsapp'].toString();
      if (map['email'] != null && map['email'].toString().isNotEmpty) email = map['email'].toString();
      if (map['working_hours'] != null && map['working_hours'].toString().isNotEmpty) hours = map['working_hours'].toString();
      if (map['gstin'] != null && map['gstin'].toString().isNotEmpty) gstin = map['gstin'].toString();
    }
  } catch (_) {}

  // 2. Try company_settings helpline fields
  try {
    final companyRes = await supabase
        .from('company_settings')
        .select()
        .limit(1)
        .maybeSingle();

    if (companyRes != null) {
      if (companyRes['company_name'] != null && companyRes['company_name'].toString().isNotEmpty) {
        name = companyRes['company_name'].toString();
      }
      if (companyRes['helpline_phone'] != null && companyRes['helpline_phone'].toString().isNotEmpty) {
        phone = companyRes['helpline_phone'].toString();
      }
      if (companyRes['whatsapp_number'] != null && companyRes['whatsapp_number'].toString().isNotEmpty) {
        whatsapp = companyRes['whatsapp_number'].toString();
      }
      if (companyRes['support_email'] != null && companyRes['support_email'].toString().isNotEmpty) {
        email = companyRes['support_email'].toString();
      }
      if (companyRes['working_hours'] != null && companyRes['working_hours'].toString().isNotEmpty) {
        hours = companyRes['working_hours'].toString();
      }
      if (companyRes['support_address'] != null && companyRes['support_address'].toString().isNotEmpty) {
        address = companyRes['support_address'].toString();
      }
    }
  } catch (_) {}

  return {
    'name': name,
    'address': address,
    'phone': phone,
    'whatsapp': whatsapp,
    'email': email,
    'working_hours': hours,
    'gstin': gstin,
  };
});

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I repressurize my IZYSmart Boiler?',
      'a':
          'Locate the filling loop valves beneath your boiler. Slowly open both black taps (turn 90 degrees) until the pressure gauge needle rises to between 1.0 and 1.5 bar. Tighten both taps securely when done.',
    },
    {
      'q': 'Why is my Heat Pump making a buzzing sound?',
      'a':
          'Subtle buzzing is normal during compressor startup. However, loud or metallic buzzing suggests loose fan casings or trapped debris. Clear any foliage from the external unit and contact support if noise continues.',
    },
    {
      'q': 'How do I bleed a cold radiator?',
      'a':
          'Turn off your central heating. Insert a radiator key into the bleed valve at the top-right of the radiator. Turn counter-clockwise until you hear air escaping. Once water drops emerge, close the valve immediately.',
    },
    {
      'q': 'What does Error Code E02 mean?',
      'a':
          'E02 indicates a system overheat or lack of water flow. Ensure all radiator valves are fully open, check that boiler pressure is above 1 bar, and try resetting the boiler. If it persists, book a technician.',
    },
    {
      'q': 'Is preventive annual maintenance covered in AMC?',
      'a':
          'Yes, an active Annual Maintenance Contract (AMC) covers comprehensive preventative tune-ups, filter cleaning, pressure and safety tests, and priority emergency booking at no extra service charge.',
    },
  ];

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) ToastService.show(context, 'Could not launch dialer: $phone', type: ToastType.error);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    String cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length == 10) {
      cleanDigits = '91$cleanDigits';
    }
    final uri = Uri.parse('https://wa.me/$cleanDigits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ToastService.show(context, 'Could not open WhatsApp.', type: ToastType.error);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Customer%20Support%20Enquiry');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) ToastService.show(context, 'Could not open email client.', type: ToastType.error);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ToastService.show(context, '$label copied to clipboard.', type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final contactAsync = ref.watch(companyContactProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Contact Us & Support',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontFamily: 'Inter',
          ),
        ),
        backgroundColor: scaffoldBg,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(companyContactProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: contactAsync.when(
            data: (company) {
              final companyName = company['name'] as String? ?? 'Insiya Solar Industry';
              final address = company['address'] as String? ?? '';
              final phone = company['phone'] as String? ?? '+91 99999 99999';
              final whatsapp = company['whatsapp'] as String? ?? phone;
              final email = company['email'] as String? ?? 'info@insiyasolar.com';
              final workingHours = company['working_hours'] as String? ?? 'Mon - Sat: 9:00 AM - 7:00 PM';
              final gstin = company['gstin'] as String? ?? '27AAAAA1111A1Z1';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Company Brand Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D28D9).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.solar_power_rounded,
                                color: Color(0xFFFBBF24),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    companyName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Official Customer Support & Care',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'We are dedicated to providing you with the highest quality solar heating & HVAC support. Reach out through any of our support channels below.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.phone_in_talk,
                          label: 'Call Us',
                          color: const Color(0xFF10B981),
                          onTap: () => _launchCall(phone),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.chat_bubble_outline,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: () => _launchWhatsApp(whatsapp),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.mail_outline,
                          label: 'Email Us',
                          color: AppColors.primary,
                          onTap: () => _launchEmail(email),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. Official Contact Details
                  Text(
                    'Company Details',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Address Card
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: AppColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Head Office & Works',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
                              tooltip: 'Copy Address',
                              onPressed: () => _copyToClipboard(address, 'Address'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          address,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Phone & Email Cards
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 16,
                    child: Column(
                      children: [
                        _buildContactRow(
                          icon: Icons.phone_outlined,
                          title: 'Customer Helpline',
                          value: phone,
                          onAction: () => _launchCall(phone),
                          actionIcon: Icons.call,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                        ),
                        const Divider(height: 20),
                        _buildContactRow(
                          icon: Icons.email_outlined,
                          title: 'Email Support',
                          value: email,
                          onAction: () => _launchEmail(email),
                          actionIcon: Icons.email,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                        ),
                        const Divider(height: 20),
                        _buildContactRow(
                          icon: Icons.chat_bubble_outline,
                          title: 'WhatsApp Helpline',
                          value: whatsapp,
                          onAction: () => _launchWhatsApp(whatsapp),
                          actionIcon: Icons.chat,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                        ),
                        const Divider(height: 20),
                        _buildContactRow(
                          icon: Icons.access_time_outlined,
                          title: 'Working Hours',
                          value: workingHours,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                        ),
                        if (gstin.isNotEmpty) ...[
                          const Divider(height: 20),
                          _buildContactRow(
                            icon: Icons.receipt_long_outlined,
                            title: 'GSTIN / Tax ID',
                            value: gstin,
                            onAction: () => _copyToClipboard(gstin, 'GSTIN'),
                            actionIcon: Icons.copy,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 4. Frequently Asked Questions
                  Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._faqs.map((faq) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 14,
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          iconColor: AppColors.accent,
                          collapsedIconColor: subtitleColor,
                          title: Text(
                            faq['q'] ?? '',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          children: [
                            Text(
                              faq['a'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 30),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => Center(child: Text('Error loading contact details: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onAction,
    IconData? actionIcon,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: subtitleColor)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
              ),
            ],
          ),
        ),
        if (onAction != null && actionIcon != null)
          IconButton(
            icon: Icon(actionIcon, size: 18, color: AppColors.accent),
            onPressed: onAction,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}
