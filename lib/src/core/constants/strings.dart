class AppConstants {
  AppConstants._();
  static const String appName = 'Afriomarkets Vendor Admin';
  static const String firstRun = 'firstRun';
  static const String firstSignIn = 'firstSignIn';
  static const String appPreferenceKey = 'appPreference';
  static const String authPreferenceKey = 'authPreference';
  static const String orderSettingsKey = 'orderSettings';
  static const String cookieKey = 'cookie';
  static const String jwtKey = 'jwt';
  static const String tokenKey = 'api_token';
  static const String supabaseTokenKey = 'sb_token';
  static const String supabaseUrlKey = 'sb_url';
  static const String supabaseAnonKey = 'sb_anon_key';
  // Default Supabase credentials (used when none are stored yet)
  static const String defaultSupabaseUrl = 'https://ehhevvujhtrjgcznewzg.supabase.co';
  static const String defaultSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoaGV2dnVqaHRyamdjem5ld3pnIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTUwNTkzMjksImV4cCI6MjAxMDYzNTMyOX0.a9M0o-hG6NemMGxXJLZb4dIzA-2r4m1bzBB8dCfr7_Q';

  static const String emailKey = 'email';
  static const String passwordKey = 'password';
  static const String themeModeKey = 'theme';
  static const String baseUrlKey = 'baseUrl';
  static const String languageKey = 'language';
  static const String useAndroidPickerKey = 'useAndroidPicker';
  static const String searchHistoryKey = 'searchHistory';
  // static const String flutterVersion = 'stable 3.19.3';
  static const String copyright = '© 2022 - 2024';
  static const String author = 'Mohammed Ragheb';
  static const int noInternetCode = 503;
  static const String noInternetMessage =
      'Check your internet connection and try again.';
  static const String unauthorizedMessage =
      'These credentials do not match our records.';
  static const String noInternetType = 'no_internet';
  static const String license = 'MIT License';
  static const String githubLink =
      'https://github.com/mllrr96/Medusa-Admin-Flutter';
  static const String githubReleasesLink =
      'https://api.github.com/repos/mllrr96/Medusa-Admin-Flutter/releases';

  // Change this to your backend url
  // This is optional since you can easily change it from the app
    static const String baseUrl = 'https://eke.afriomarkets.com';
  // static const String baseUrl = 'http://localhost:9000';
}
