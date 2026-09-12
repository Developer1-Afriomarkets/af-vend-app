import 'logistics_org_settings_view.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/core/utils/medusa_sliver_app_bar.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medusa_admin/src/features/store_details/presentation/bloc/store/store_bloc.dart';
import 'package:medusa_admin/src/core/extensions/snack_bar_extension.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

@RoutePage()
class StoreSettingsView extends StatelessWidget {
  const StoreSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppScope>(
      valueListenable: AppScopeService.activeScopeNotifier,
      builder: (context, activeScope, _) {
        final String pageTitle;
        switch (activeScope) {
          case AppScope.logistics:
            pageTitle = 'Logistics Hub & Fleet Settings';
            break;
          case AppScope.rider:
            pageTitle = 'Rider Cockpit & Shift Settings';
            break;
          case AppScope.admin:
            pageTitle = 'Platform Administration';
            break;
          case AppScope.vendor:
            pageTitle = 'Store Settings';
            break;
        }

        return Scaffold(
          drawer: null,
          drawerEdgeDragWidth: context.drawerEdgeDragWidth,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              MedusaSliverAppBar(
                title: Text(pageTitle),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () {
                    if (context.router.canPop()) {
                      context.router.maybePop();
                    } else {
                      try {
                        context.tabsRouter.setActiveIndex(0);
                      } catch (_) {
                        context.router.maybePop();
                      }
                    }
                  },
                ),
              ),
            ],
            body: BlocBuilder<StoreBloc, StoreState>(
              builder: (context, state) {
                final store = state.maybeWhen(
                  store: (store) => store,
                  stores: (response) => response.stores.firstOrNull,
                  orElse: () {
                    state.whenOrNull(
                      initial: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.read<StoreBloc>().add(const StoreEvent.loadStores(null));
                      }),
                      error: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
                        context.read<StoreBloc>().add(const StoreEvent.loadStores(null));
                      }),
                    );
                    return null;
                  },
                );

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  children: [
                    ScopedHeroCard(store: store, scope: activeScope),
                    const SizedBox(height: 12.0),
                    ..._buildScopedSettingsTiles(context, activeScope),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildScopedSettingsTiles(BuildContext context, AppScope scope) {
    switch (scope) {
      case AppScope.logistics:
        return [
          const SettingsSectionHeader(title: 'Logistics Hub & Fleet Operations'),
          SettingsCardTile(
            leadingIcon: LucideIcons.building2,
            iconColor: const Color(0xFF059669),
            title: 'Logistics Organization Affairs & Profile',
            subtitle: 'Manage company identity, CAC registration, coverage zones, fleet size, and dispatch SLAs',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LogisticsOrgSettingsView()),
            ),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.gitFork,
            iconColor: const Color(0xFF059669),
            title: 'Collection Stations & Drop Centers',
            subtitle: 'Manage regional intake stations, operating hours and handling capacities',
            onTap: () => context.pushRoute(const PickupRequestsDeliveriesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Active Deliveries & Fleet Manifests',
            subtitle: 'Review assigned shipments, driver manifests and live delivery states',
            onTap: () => context.pushRoute(DeliveriesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.swap_vert_circle_outlined,
            iconColor: const Color(0xFF059669),
            title: 'Merchant Package Pickups',
            subtitle: 'Coordinate intake jobs and merchant fulfillment handovers',
            onTap: () => context.pushRoute(PickupRequestsRoute()),
          ),

          if (AppScopeService.isLogisticsAdmin) ...[
            const SettingsSectionHeader(title: 'Logistics Settlement & Bank Account'),
            SettingsCardTile(
              leadingIcon: LucideIcons.landmark,
              iconColor: const Color(0xFF10B981),
              title: 'Corporate Settlement Account & Bank Details',
              subtitle: 'Configure verified business bank account (CAC/RC) for automated freight payouts',
              onTap: () => context.pushRoute(const VendorWalletRoute()),
            ),
          ],
          SettingsCardTile(
            leadingIcon: LucideIcons.wallet,
            iconColor: Colors.green.shade600,
            title: 'Organization Clearing Wallet',
            subtitle: 'Monitor clearing balance, freight collections, and instant payout withdrawals',
            onTap: () => context.pushRoute(const VendorWalletRoute()),
          ),

          const SettingsSectionHeader(title: 'Fleet & Staff Management'),
          SettingsCardTile(
            leadingIcon: LucideIcons.users,
            iconColor: const Color(0xFF059669),
            title: 'Logistics Team & Staff',
            subtitle: 'Manage dispatch operators, fleet managers, and team member permissions',
            onTap: () => context.pushRoute(const TeamRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.userPlus,
            iconColor: const Color(0xFF2563EB),
            title: 'Staff Invitations',
            subtitle: 'Invite dispatchers, riders, and operations staff to join your organization',
            onTap: () => context.pushRoute(const InvitesRoute()),
          ),

          const SettingsSectionHeader(title: 'Cross-Role Business Expansion'),
          SettingsCardTile(
            leadingIcon: Icons.storefront_rounded,
            iconColor: const Color(0xFFE48629),
            title: AppScopeService.allowedScopes.contains(AppScope.vendor)
                ? 'Switch to Vendor Store Mode'
                : 'Create / Register Vendor Store',
            subtitle: AppScopeService.allowedScopes.contains(AppScope.vendor)
                ? 'You have an active vendor merchant account. Tap to switch operational scope.'
                : 'Expand your business into retail by registering a merchant storefront on Afrio Marketplace.',
            onTap: () async {
              if (AppScopeService.allowedScopes.contains(AppScope.vendor)) {
                await AppScopeService.setScope(AppScope.vendor);
                if (context.mounted) {
                  context.showSnackBar('Switched to Vendor Store Mode');
                }
              } else {
                context.pushRoute(const AccountUpdateWizardRoute());
              }
            },
          ),

          const SettingsSectionHeader(title: 'Account & Device'),
          SettingsCardTile(
            leadingIcon: LucideIcons.user,
            iconColor: Colors.blueGrey.shade600,
            title: 'Dispatcher Profile',
            subtitle: 'Manage personal contact, login credentials, and notifications',
            onTap: () => context.pushRoute(const PersonalInformationRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.settings,
            iconColor: Colors.blueGrey.shade700,
            title: 'App Preferences',
            subtitle: 'Manage app theme, notification sounds, and display options',
            onTap: () => context.pushRoute(const AppSettingsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.logOut,
            iconColor: Colors.red.shade600,
            title: 'Sign Out',
            subtitle: 'Safely logout from your logistics organization session',
            onTap: () => _signOut(context),
          ),
        ];

      case AppScope.rider:
        return [
          const SettingsSectionHeader(title: 'Shift Availability & Live Runs'),
          ValueListenableBuilder<bool>(
            valueListenable: AppScopeService.isRiderOnlineNotifier,
            builder: (context, isOnline, _) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10.0),
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF10B981).withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade400,
                    width: 1.2,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF10B981) : Colors.grey.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOnline ? Icons.two_wheeler_rounded : Icons.power_settings_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isOnline ? 'Active On-Duty · Ready for Drops' : 'Off-Duty · Shift Inactive',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    isOnline ? 'You will receive incoming dispatch jobs and pickup alerts' : 'Toggle to start your delivery shift',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  trailing: Switch(
                    value: isOnline,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) => AppScopeService.toggleRiderOnline(val),
                  ),
                ),
              );
            },
          ),
          SettingsCardTile(
            leadingIcon: Icons.delivery_dining_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'My Deliveries Queue',
            subtitle: 'Review assigned customer packages, addresses, and delivery confirmation',
            onTap: () => context.pushRoute(DeliveriesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.qr_code_scanner_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: 'Assigned Pickups & Scanning',
            subtitle: 'Execute merchant package intake with barcode or OTP check',
            onTap: () => context.pushRoute(PickupRequestsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.map_rounded,
            iconColor: Colors.teal.shade600,
            title: 'Drop-off Stations & Locker Map',
            subtitle: 'Find nearest collection hub, drop desk and dispatch lockers',
            onTap: () => context.pushRoute(const PickupRequestsDeliveriesRoute()),
          ),

          const SettingsSectionHeader(title: 'Earnings & Payouts'),
          SettingsCardTile(
            leadingIcon: LucideIcons.wallet,
            iconColor: Colors.green.shade600,
            title: 'Rider Earnings & Tips',
            subtitle: 'View completed delivery fees, customer tips, and instant payouts',
            onTap: () => context.pushRoute(const VendorWalletRoute()),
          ),

          const SettingsSectionHeader(title: 'Rider Profile & App'),
          SettingsCardTile(
            leadingIcon: LucideIcons.user,
            iconColor: Colors.blueGrey.shade600,
            title: 'Rider Profile & Contact',
            subtitle: 'Update phone number, vehicle type, and emergency contacts',
            onTap: () => context.pushRoute(const PersonalInformationRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.settings,
            iconColor: Colors.blueGrey.shade700,
            title: 'Navigation & Sounds',
            subtitle: 'Turn-by-turn preferences, delivery chimes, and battery saver',
            onTap: () => context.pushRoute(const AppSettingsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.logOut,
            iconColor: Colors.red.shade600,
            title: 'End Shift & Sign Out',
            subtitle: 'Safely logout from your courier session',
            onTap: () => _signOut(context),
          ),
        ];

      case AppScope.admin:
        return [
          const SettingsSectionHeader(title: 'Platform Master Controls'),
          SettingsCardTile(
            leadingIcon: LucideIcons.store,
            iconColor: Colors.purple.shade600,
            title: 'Tenants & Store Directory',
            subtitle: 'Oversight across all registered marketplace stores and vendors',
            onTap: () => context.pushRoute(const StoreDetailsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.hub_rounded,
            iconColor: const Color(0xFF059669),
            title: 'Global Logistics Grid & Stations',
            subtitle: 'Monitor all regional partner hubs, collection stations, and fleets',
            onTap: () => context.pushRoute(const PickupRequestsDeliveriesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.local_shipping_rounded,
            iconColor: Colors.blue.shade600,
            title: 'Platform Deliveries & Parcel Audit',
            subtitle: 'Inspect all active parcel transits, proofs of delivery, and disputes',
            onTap: () => context.pushRoute(DeliveriesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.users,
            iconColor: Colors.teal.shade600,
            title: 'Staff Users & Role Permissions',
            subtitle: 'Manage administrative team access, roles, and privileges',
            onTap: () => context.pushRoute(const TeamRoute()),
          ),

          const SettingsSectionHeader(title: 'Markets, Currencies & Rules'),
          SettingsCardTile(
            leadingIcon: LucideIcons.coins,
            iconColor: Colors.amber.shade600,
            title: 'Global Currencies & Exchange',
            subtitle: 'Configure base exchange rates and multi-currency support',
            onTap: () => context.pushRoute(const CurrenciesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.location_on_outlined,
            iconColor: Colors.red.shade600,
            title: 'Operational Jurisdictions & Regions',
            subtitle: 'Platform operating regions, shipping zones, and tax profiles',
            onTap: () => context.pushRoute(const RegionsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.attach_money_outlined,
            iconColor: Colors.amber.shade700,
            title: 'Return Policies & Reasons',
            subtitle: 'Standardized return rules and dispute reasons',
            onTap: () => context.pushRoute(const ReturnReasonsRoute()),
          ),

          const SettingsSectionHeader(title: 'Developer & Integrations'),
          SettingsCardTile(
            leadingIcon: LucideIcons.rotateCcwKey,
            iconColor: Colors.pink.shade600,
            title: 'Publishable API Keys',
            subtitle: 'Storefront public integration keys',
            onTap: () => context.pushRoute(const PublishableApiKeysRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.key,
            iconColor: Colors.deepPurple.shade600,
            title: 'Secret API Keys',
            subtitle: 'Secure server-to-server keys and webhook endpoints',
            onTap: () => context.pushRoute(const SecretApiKeysRoute()),
          ),

          const SettingsSectionHeader(title: 'System & Security'),
          SettingsCardTile(
            leadingIcon: LucideIcons.settings,
            iconColor: Colors.blueGrey.shade700,
            title: 'System App Settings',
            subtitle: 'Platform diagnostic tools, logs, and theme configuration',
            onTap: () => context.pushRoute(const AppSettingsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.logOut,
            iconColor: Colors.red.shade600,
            title: 'Sign Out Admin Session',
            subtitle: 'Terminate elevated session safely',
            onTap: () => _signOut(context),
          ),
        ];

      case AppScope.vendor:
        return [
          const SettingsSectionHeader(title: 'Store Operations'),
          SettingsCardTile(
            leadingIcon: LucideIcons.wand2,
            iconColor: Colors.deepPurple.shade600,
            title: 'Store & Profile Setup Wizard',
            subtitle: 'Update your personal info, store address, and market details step-by-step',
            onTap: () => context.pushRoute(const AccountUpdateWizardRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.store,
            iconColor: Colors.blue.shade600,
            title: 'Store Details',
            subtitle: 'Manage your store details, public name, and brand',
            onTap: () => context.pushRoute(const StoreDetailsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.coins,
            iconColor: Colors.amber.shade600,
            title: 'Currencies',
            subtitle: 'Manage store currencies, default currency, and exchange support',
            onTap: () => context.pushRoute(const CurrenciesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.call_split_outlined,
            iconColor: Colors.cyan.shade600,
            title: 'Sales Channels',
            subtitle: 'Control availability across web and app channels',
            onTap: () => context.pushRoute(const SalesChannelsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.local_shipping_outlined,
            iconColor: Colors.indigo.shade600,
            title: 'Stock Locations',
            subtitle: 'Manage physical warehouse and inventory stock locations',
            onTap: () => context.pushRoute(const StockLocationsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.local_shipping,
            iconColor: Colors.purple.shade700,
            title: 'Shipping Profiles',
            subtitle: 'Configure customized shipping rates and fulfillment rules',
            onTap: () => context.pushRoute(const ShippingProfilesRoute()),
          ),

          const SettingsSectionHeader(title: 'Finance & Payouts'),
          SettingsCardTile(
            leadingIcon: LucideIcons.wallet,
            iconColor: Colors.green.shade600,
            title: 'Vendor Wallet & Payout Accounts',
            subtitle: 'Manage balance, business bank accounts, settlements, and payout requests',
            onTap: () => context.pushRoute(const VendorWalletRoute()),
          ),

          const SettingsSectionHeader(title: 'Logistics Grid'),
          SettingsCardTile(
            leadingIcon: Icons.hub_rounded,
            iconColor: const Color(0xFF059669),
            title: 'Collection Stations & Drop Centers',
            subtitle: 'Locate nearby drop desks to deposit prepared customer packages',
            onTap: () => context.pushRoute(const PickupRequestsDeliveriesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFFE48629),
            title: 'Logistics Partner Onboarding',
            subtitle: 'Register delivery vehicles and join the Afrio logistics grid as a carrier',
            onTap: () => context.pushRoute(const LogisticsOnboardingWizardRoute()),
          ),

          const SettingsSectionHeader(title: 'Team & Policies'),
          SettingsCardTile(
            leadingIcon: LucideIcons.users,
            iconColor: Colors.teal.shade600,
            title: 'Store Team',
            subtitle: 'View and manage store staff and role permissions',
            onTap: () => context.pushRoute(const TeamRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.userPlus,
            iconColor: const Color(0xFF2563EB),
            title: 'Staff Invitations',
            subtitle: 'Invite collaborators and staff to manage your storefront',
            onTap: () => context.pushRoute(const InvitesRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.location_on_outlined,
            iconColor: Colors.red.shade600,
            title: 'Operating Regions',
            subtitle: 'Configure customer delivery regions and operational countries',
            onTap: () => context.pushRoute(const RegionsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: Icons.attach_money_outlined,
            iconColor: Colors.amber.shade700,
            title: 'Return Reasons',
            subtitle: 'Define standardized options for product returns',
            onTap: () => context.pushRoute(const ReturnReasonsRoute()),
          ),

          const SettingsSectionHeader(title: 'Account & App'),
          SettingsCardTile(
            leadingIcon: LucideIcons.user,
            iconColor: Colors.blueGrey.shade600,
            title: 'My Profile',
            subtitle: 'Manage account profile information',
            onTap: () => context.pushRoute(const PersonalInformationRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.settings,
            iconColor: Colors.blueGrey.shade700,
            title: 'App Settings',
            subtitle: 'Manage app theme, preferences, and notifications',
            onTap: () => context.pushRoute(const AppSettingsRoute()),
          ),
          SettingsCardTile(
            leadingIcon: LucideIcons.logOut,
            iconColor: Colors.red.shade600,
            title: 'Sign Out',
            subtitle: 'Logout from your store account safely',
            onTap: () => _signOut(context),
          ),
        ];
    }
  }
}

class ScopedHeroCard extends StatelessWidget {
  const ScopedHeroCard({super.key, this.store, required this.scope});
  final Store? store;
  final AppScope scope;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String title;
    final String subtitle;
    final String badge;
    final String avatarSymbol;
    final List<Color> gradientColors;

    switch (scope) {
      case AppScope.logistics:
        final org = AppScopeService.organizationName;
        title = org.isNotEmpty ? org : (store?.name ?? 'Afrio Logistics Hub');
        subtitle = 'Regional Fleet & Freight Intake Hub';
        badge = 'Verified Logistics Partner 🚚';
        avatarSymbol = '🚚';
        gradientColors = isDark
            ? [const Color(0xFF064E3B), const Color(0xFF022C22)]
            : [const Color(0xFF059669), const Color(0xFF10B981)];
        break;
      case AppScope.rider:
        final riderName = AppScopeService.displayName;
        title = riderName.isNotEmpty ? riderName : 'Courier Cockpit';
        subtitle = 'Fast Mile Delivery Courier';
        badge = AppScopeService.isRiderOnline ? 'Online · Active Shift' : 'Offline';
        avatarSymbol = '🛵';
        gradientColors = isDark
            ? [const Color(0xFF1E3A8A), const Color(0xFF0F172A)]
            : [const Color(0xFF2563EB), const Color(0xFF3B82F6)];
        break;
      case AppScope.admin:
        title = 'Afriomarkets HQ';
        subtitle = 'Master Platform Administration';
        badge = 'Platform Superadmin 🛡️';
        avatarSymbol = '🛡️';
        gradientColors = isDark
            ? [const Color(0xFF4C1D95), const Color(0xFF1E1B4B)]
            : [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)];
        break;
      case AppScope.vendor:
        title = store?.name ?? 'Afriomarkets Store';
        final defaultCurrency = store?.supportedCurrencies
                ?.firstWhere((c) => c.isDefault,
                    orElse: () => const StoreCurrency(
                        id: '',
                        currencyCode: 'USD',
                        storeId: '',
                        isDefault: true,
                        currency: Currency(
                            code: 'USD',
                            symbol: r'$',
                            symbolNative: r'$',
                            name: 'US Dollar')))
                .currencyCode
                .toUpperCase() ??
            'USD';
        subtitle = 'Default Currency: $defaultCurrency';
        badge = 'Verified Storefront 🛍️';
        avatarSymbol = title.isNotEmpty ? title.substring(0, title.length >= 2 ? 2 : 1).toUpperCase() : 'AM';
        gradientColors = isDark
            ? [const Color(0xFF1B2B0C), const Color(0xFF11170C)]
            : [const Color(0xFF344F16), const Color(0xFFE48629)];
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: isDark ? 0.3 : 0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              avatarSymbol,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: avatarSymbol.length > 2 ? 24 : 20,
              ),
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsCardTile extends StatelessWidget {
  const SettingsCardTile({
    super.key,
    required this.leadingIcon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData leadingIcon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1800) : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    leadingIcon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              fontSize: 14,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                              fontSize: 11.5,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, top: 16.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
      ),
    );
  }
}

void _signOut(BuildContext context) async {
  await showOkCancelAlertDialog(
          context: context,
          title: 'Sign out',
          message: 'Are you sure you want to sign out?',
          okLabel: 'Sign Out',
          isDestructiveAction: true)
      .then(
    (value) async {
      if (value == OkCancelResult.ok && context.mounted) {
        context.read<AuthenticationBloc>().add(const AuthenticationEvent.logOut());
        if (context.mounted) { context.router.replaceAll([const AuthenticationRoute()]); }
      }
    },
  );
}
