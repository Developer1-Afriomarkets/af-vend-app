import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppScope {
  vendor,
  logistics,
  rider,
  admin;

  String get label {
    switch (this) {
      case AppScope.vendor:
        return 'Vendor Operations';
      case AppScope.logistics:
        return 'Logistics Hub & Dispatch';
      case AppScope.rider:
        return 'Rider & Delivery Runs';
      case AppScope.admin:
        return 'Administrative Overview';
    }
  }

  String get shortLabel {
    switch (this) {
      case AppScope.vendor:
        return 'Vendor';
      case AppScope.logistics:
        return 'Logistics';
      case AppScope.rider:
        return 'Rider';
      case AppScope.admin:
        return 'Admin';
    }
  }

  String get badgeEmoji {
    switch (this) {
      case AppScope.vendor:
        return '🛍️';
      case AppScope.logistics:
        return '🚚';
      case AppScope.rider:
        return '🛵';
      case AppScope.admin:
        return '🛡️';
    }
  }

  String get description {
    switch (this) {
      case AppScope.vendor:
        return 'Manage store products, sales orders, packaging readiness & pickup requests';
      case AppScope.logistics:
        return 'Handle regional collection stations, inbound packages & fleet dispatch';
      case AppScope.rider:
        return 'Execute assigned delivery runs, contact customers & submit proof of delivery';
      case AppScope.admin:
        return 'Full platform oversight across all stores, logistics partners & stations';
    }
  }

  IconData get icon {
    switch (this) {
      case AppScope.vendor:
        return Icons.storefront_rounded;
      case AppScope.logistics:
        return Icons.local_shipping_rounded;
      case AppScope.rider:
        return Icons.two_wheeler_rounded;
      case AppScope.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AppScope.vendor:
        return const Color(0xFF1B3A0A); // Forest Green
      case AppScope.logistics:
        return const Color(0xFF059669); // Emerald Green
      case AppScope.rider:
        return const Color(0xFF2563EB); // Vibrant Blue
      case AppScope.admin:
        return const Color(0xFF7C3AED); // Deep Purple
    }
  }

  Color get accentColor {
    switch (this) {
      case AppScope.vendor:
        return const Color(0xFFE48629); // Amber
      case AppScope.logistics:
        return const Color(0xFF10B981); // Bright Emerald
      case AppScope.rider:
        return const Color(0xFF3B82F6); // Sky Blue
      case AppScope.admin:
        return const Color(0xFF8B5CF6); // Violet
    }
  }
}

class AppScopeService {
  static const String _prefKey = 'afrio_active_app_scope';
  static const String _prefAccountTypeKey = 'afrio_user_account_type';
  static const String _prefRoleKey = 'afrio_user_role';
  static const String _prefAllowedScopesKey = 'afrio_user_allowed_scopes';

  static Map<String, dynamic>? _cachedMetadata;
  static String? _cachedRole;

  static Map<String, dynamic>? get cachedMetadata => _cachedMetadata;
  static String? get cachedRole => _cachedRole;

  static String get displayName {
    final meta = _cachedMetadata ?? {};
    final name = (meta['business_name'] ?? meta['company_name'] ?? meta['store_name'] ?? meta['full_name'] ?? meta['name'] ?? '').toString().trim();
    return name;
  }

  static String get organizationName {
    final meta = _cachedMetadata ?? {};
    final name = (meta['company_name'] ?? meta['business_name'] ?? meta['org_name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    return 'Afriomarkets Logistics Hub';
  }

  static String? get currentLogisticsOrgId {
    final meta = _cachedMetadata ?? {};
    final orgId = meta['logistics_org_id']?.toString().trim();
    if (orgId != null && orgId.isNotEmpty && orgId != 'null') return orgId;
    return null;
  }

  static String? get currentStoreId {
    final meta = _cachedMetadata ?? {};
    final storeId = meta['store_id']?.toString().trim();
    if (storeId != null && storeId.isNotEmpty && storeId != 'null') return storeId;
    return null;
  }

  static final ValueNotifier<AppScope> activeScopeNotifier =
      ValueNotifier<AppScope>(AppScope.vendor);

  static final ValueNotifier<List<AppScope>> allowedScopesNotifier =
      ValueNotifier<List<AppScope>>([AppScope.vendor]);

  static final ValueNotifier<bool> isRiderOnlineNotifier =
      ValueNotifier<bool>(true);

  static AppScope get currentScope => activeScopeNotifier.value;
  static AppScope get activeScope => activeScopeNotifier.value;
  static List<AppScope> get allowedScopes => allowedScopesNotifier.value;
  static bool get hasMultipleScopes => allowedScopes.length > 1;
  static bool get isRiderOnline => isRiderOnlineNotifier.value;

  static bool get isVendor => currentScope == AppScope.vendor;
  static bool get isLogistics => currentScope == AppScope.logistics;
  static bool get isRider => currentScope == AppScope.rider;
  static bool get isAdmin => currentScope == AppScope.admin;

  static void toggleRiderOnline([bool? value]) {
    isRiderOnlineNotifier.value = value ?? !isRiderOnlineNotifier.value;
  }

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAccountType = prefs.getString(_prefAccountTypeKey);
      final savedRole = prefs.getString(_prefRoleKey);
      final savedAllowedScopeNames = prefs.getStringList(_prefAllowedScopesKey);

      if (savedAccountType != null || savedRole != null || savedAllowedScopeNames != null) {
        _cachedRole = savedRole;
        _cachedMetadata = {
          if (savedAccountType != null) 'account_type': savedAccountType,
          if (savedAllowedScopeNames != null) 'allowed_scopes': savedAllowedScopeNames,
        };
        final computedScopes = _computeScopes(
          role: savedRole,
          metadata: _cachedMetadata,
        );
        allowedScopesNotifier.value = computedScopes;
      }

      final savedIndex = prefs.getInt(_prefKey);
      if (savedIndex != null &&
          savedIndex >= 0 &&
          savedIndex < AppScope.values.length) {
        final savedScope = AppScope.values[savedIndex];
        if (allowedScopes.contains(savedScope)) {
          activeScopeNotifier.value = savedScope;
        } else if (allowedScopes.isNotEmpty) {
          activeScopeNotifier.value = allowedScopes.first;
        }
      } else if (allowedScopes.isNotEmpty) {
        activeScopeNotifier.value = allowedScopes.first;
      }
    } catch (_) {}
  }

  static Future<void> addAllowedScope(AppScope newScope, {bool switchToNewScope = false}) async {
    final current = List<AppScope>.from(allowedScopesNotifier.value);
    if (!current.contains(newScope)) {
      current.add(newScope);
      allowedScopesNotifier.value = current;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final names = current.map((s) => s.name).toList();
      await prefs.setStringList(_prefAllowedScopesKey, names);

      _cachedMetadata ??= {};
      _cachedMetadata!['allowed_scopes'] = names;
    } catch (_) {}

    if (switchToNewScope) {
      await setScope(newScope);
    }
  }

  static Future<void> setUserMetadata(Map<String, dynamic>? metadata, [String? role]) async {
    if (metadata != null) {
      _cachedMetadata = Map<String, dynamic>.from(metadata);
    }
    if (role != null) {
      _cachedRole = role;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final accountType = metadata?['account_type']?.toString();
      if (accountType != null && accountType.isNotEmpty) {
        await prefs.setString(_prefAccountTypeKey, accountType);
      }
      if (role != null && role.isNotEmpty) {
        await prefs.setString(_prefRoleKey, role);
      }
    } catch (_) {}

    final scopes = _computeScopes(role: _cachedRole, metadata: _cachedMetadata);
    allowedScopesNotifier.value = scopes;

    if (!scopes.contains(activeScope)) {
      await setScope(scopes.first);
    }
  }

  static Future<void> setScope(AppScope scope) async {
    final targetScope = allowedScopes.contains(scope)
        ? scope
        : (allowedScopes.isNotEmpty ? allowedScopes.first : scope);

    activeScopeNotifier.value = targetScope;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, targetScope.index);
    } catch (_) {}
  }

  static List<AppScope> _computeScopes({String? role, Map<String, dynamic>? metadata, dynamic user}) {
    final roleStr = (role ?? '').toLowerCase();
    if (roleStr.contains('admin')) {
      return AppScope.values;
    }

    final meta = metadata ?? {};
    final accountType = (meta['account_type'] ?? '').toString().toLowerCase();
    final List<AppScope> scopes = [];

    if (meta['allowed_scopes'] is List) {
      for (final s in meta['allowed_scopes'] as List) {
        final str = s.toString().toLowerCase();
        if (str == 'vendor' && !scopes.contains(AppScope.vendor)) scopes.add(AppScope.vendor);
        if ((str == 'logistics' || str == 'logistics_org') && !scopes.contains(AppScope.logistics)) {
          scopes.add(AppScope.logistics);
        }
        if ((str == 'rider' || str == 'logistics_staff') && !scopes.contains(AppScope.rider)) {
          scopes.add(AppScope.rider);
        }
        if (str == 'admin' && !scopes.contains(AppScope.admin)) scopes.add(AppScope.admin);
      }
    }

    if (accountType == 'logistics_org') {
      if (!scopes.contains(AppScope.logistics)) scopes.add(AppScope.logistics);
      if (!scopes.contains(AppScope.rider)) scopes.add(AppScope.rider);
    } else if (accountType == 'logistics_staff' || accountType == 'rider') {
      if (!scopes.contains(AppScope.rider)) scopes.add(AppScope.rider);
      if (!scopes.contains(AppScope.logistics)) scopes.add(AppScope.logistics);
    } else if (accountType == 'admin') {
      if (!scopes.contains(AppScope.admin)) scopes.add(AppScope.admin);
    } else if (accountType == 'vendor') {
      if (!scopes.contains(AppScope.vendor)) scopes.add(AppScope.vendor);
    }

    // Logistics Organization binding (e.g. Swift Air Org 4)
    final logisticsOrgId = (meta['logistics_org_id'] ?? '').toString().trim();
    if (logisticsOrgId.isNotEmpty && logisticsOrgId != 'null') {
      if (!scopes.contains(AppScope.logistics)) scopes.add(AppScope.logistics);
      if (!scopes.contains(AppScope.rider)) scopes.add(AppScope.rider);
    }

    // Vendor Store binding (e.g. store_id exists on user or metadata)
    String? userStoreId;
    try {
      userStoreId = user?.storeId?.toString() ?? user?.store_id?.toString() ?? meta['store_id']?.toString();
    } catch (_) {}
    if (userStoreId != null && userStoreId.isNotEmpty && userStoreId != 'null' && !scopes.contains(AppScope.vendor)) {
      scopes.add(AppScope.vendor);
    }

    if (scopes.isEmpty) {
      scopes.add(AppScope.vendor);
    }

    return scopes;
  }

  static void updateAllowedScopesFromUser(dynamic user) {
    if (user == null) {
      if (_cachedMetadata != null || _cachedRole != null) {
        final scopes = _computeScopes(role: _cachedRole, metadata: _cachedMetadata);
        allowedScopesNotifier.value = scopes;
        if (!scopes.contains(activeScope)) setScope(scopes.first);
        return;
      }
      allowedScopesNotifier.value = [AppScope.vendor];
      return;
    }

    try {
      String? role;
      Map<String, dynamic>? meta;

      try {
        role = user.role?.toString();
      } catch (_) {}

      try {
        if (user.metadata is Map) {
          meta = Map<String, dynamic>.from(user.metadata as Map);
        }
      } catch (_) {}

      role ??= _cachedRole;
      meta ??= _cachedMetadata;

      if (meta != null && meta.isNotEmpty) {
        _cachedMetadata = meta;
      }
      if (role != null && role.isNotEmpty) {
        _cachedRole = role;
      }

      final scopes = _computeScopes(role: role, metadata: meta, user: user);
      allowedScopesNotifier.value = scopes;

      // If user's account_type is logistics_org, automatically activate logistics scope unless already set
      final accountType = (meta?['account_type'] ?? '').toString().toLowerCase();
      if (accountType == 'logistics_org' && activeScope != AppScope.logistics) {
        setScope(AppScope.logistics);
      } else if (!scopes.contains(activeScope)) {
        setScope(scopes.first);
      }
    } catch (_) {
      if (_cachedMetadata != null) {
        final scopes = _computeScopes(role: _cachedRole, metadata: _cachedMetadata);
        allowedScopesNotifier.value = scopes;
        if (!scopes.contains(activeScope)) setScope(scopes.first);
      } else {
        allowedScopesNotifier.value = [AppScope.vendor];
      }
    }
  }
}
