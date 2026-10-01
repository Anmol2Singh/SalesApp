// lib/core/config/app_config.dart

/// Compile-time application configuration passed via `--dart-define` or `--dart-define-from-file`.
/// Provides production-safe fallbacks for seamless local development across Android, iOS, Windows, and Web.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dnhbtkhcjpkthvyhyzmt.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuaGJ0a2hjanBrdGh2eWh5em10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNTQxODgsImV4cCI6MjA5NzYzMDE4OH0.oMh-wN5YgqnxTBy_KOvNCQIhPu1G2xwFnfkdwaN81u8',
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyACzUbNtqpwhXMkVuGa-DAPly3TuageIVM',
  );

  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_TgL4kbeymcFTr8',
  );

  static const String razorpayKeySecret = String.fromEnvironment(
    'RAZORPAY_KEY_SECRET',
    defaultValue: 'PilWo0tvB7RvaEuzcL4CAJFo',
  );

  static const String backendApiUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: '',
  );

  static const String fast2SmsApiKey = String.fromEnvironment(
    'FAST2SMS_API_KEY',
    defaultValue: '',
  );

  static const String whatsappPhoneId = String.fromEnvironment(
    'WHATSAPP_PHONE_ID',
    defaultValue: '',
  );

  static const String whatsappAccessToken = String.fromEnvironment(
    'WHATSAPP_ACCESS_TOKEN',
    defaultValue: '',
  );

  static const String whatsappTemplateName = String.fromEnvironment(
    'WHATSAPP_TEMPLATE_NAME',
    defaultValue: 'otp_verification',
  );
}
