import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/core/utils/medusa_sliver_app_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:medusa_admin/src/features/store_details/presentation/bloc/store/store_bloc.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

@RoutePage()
class StoreSettingsView extends StatelessWidget {
  const StoreSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: null,
      drawerEdgeDragWidth: context.drawerEdgeDragWidth,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          MedusaSliverAppBar(
            title: const Text('Store Settings'),
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
                StoreHeroCard(store: store),
                const SizedBox(height: 12.0),
                const SettingsSectionHeader(title: 'General'),
                SettingsCardTile(
                  leadingIcon: LucideIcons.wand2,
                  iconColor: Colors.deepPurple.shade600,
                  title: 'Store & Profile Setup Wizard',
                  subtitle: 'Update your personal info, store address, and market details step-by-step',
                  onTap: () => context.pushRoute(const AccountUpdateWizardRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: LucideIcons.wallet,
                  iconColor: Colors.green.shade600,
                  title: 'Vendor Wallet & Payout Accounts',
                  subtitle: 'Manage balance, business bank accounts, settlements, and payout requests',
                  onTap: () => context.pushRoute(const VendorWalletRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: LucideIcons.store,
                  iconColor: Colors.blue.shade600,
                  title: 'Store Details',
                  subtitle: 'Manage your store details and name',
                  onTap: () => context.pushRoute(const StoreDetailsRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: LucideIcons.coins,
                  iconColor: Colors.amber.shade600,
                  title: 'Currencies',
                  subtitle: 'Manage store currencies, default store currency, and exchange support',
                  onTap: () => context.pushRoute(const CurrenciesRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: LucideIcons.users,
                  iconColor: Colors.teal.shade600,
                  title: 'Users',
                  subtitle: 'View and manage store users',
                  onTap: () => context.pushRoute(const TeamRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: Icons.location_on_outlined,
                  iconColor: Colors.red.shade600,
                  title: 'Regions',
                  subtitle: 'Configure operational regions and currencies',
                  onTap: () => context.pushRoute(const RegionsRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: Icons.attach_money_outlined,
                  iconColor: Colors.amber.shade700,
                  title: 'Return Reasons',
                  subtitle: 'Define options for order returns',
                  onTap: () => context.pushRoute(const ReturnReasonsRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: LucideIcons.box,
                  iconColor: Colors.purple.shade600,
                  title: 'Product Types',
                  subtitle: 'Organize items by standard types',
                  onTap: () => context.pushRoute(const ProductTypesRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: LucideIcons.tags,
                  iconColor: Colors.deepOrange.shade600,
                  title: 'Product Tags',
                  subtitle: 'Create and filter tags for product classification',
                  onTap: () => context.pushRoute(const ProductTagsRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: Icons.call_split_outlined,
                  iconColor: Colors.cyan.shade600,
                  title: 'Sales Channels',
                  subtitle: 'Control availability across digital channels',
                  onTap: () => context.pushRoute(const SalesChannelsRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: Icons.local_shipping_outlined,
                  iconColor: Colors.indigo.shade600,
                  title: 'Locations',
                  subtitle: 'Manage physical inventory stock locations',
                  onTap: () => context.pushRoute(const StockLocationsRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: Icons.local_shipping,
                  iconColor: Colors.purple.shade700,
                  title: 'Shipping Profiles',
                  subtitle: 'Configure custom shipping rules',
                  onTap: () => context.pushRoute(const ShippingProfilesRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: Icons.delivery_dining_outlined,
                  iconColor: Colors.green.shade600,
                  title: 'Shipping Option Types',
                  subtitle: 'Set up delivery methods and providers',
                  onTap: () => context.pushRoute(ShippingOptionTypesRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: Icons.group_outlined,
                  iconColor: Colors.indigo.shade400,
                  title: 'Invites',
                  subtitle: 'Manage pending team invitations',
                  onTap: () => context.pushRoute(const InvitesRoute()),
                ),
                const SettingsSectionHeader(title: 'Developer'),
                SettingsCardTile(
                  leadingIcon: LucideIcons.rotateCcwKey,
                  iconColor: Colors.pink.shade600,
                  title: 'Publishable API Keys',
                  subtitle: 'Manage client-side API keys',
                  onTap: () => context.pushRoute(const PublishableApiKeysRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: LucideIcons.key,
                  iconColor: Colors.deepPurple.shade600,
                  title: 'Secret API Keys',
                  subtitle: 'Generate secure server-side tokens',
                  onTap: () => context.pushRoute(const SecretApiKeysRoute()),
                ),
                const SettingsSectionHeader(title: 'My Account'),
                 SettingsCardTile(
                  leadingIcon: LucideIcons.user,
                  iconColor: Colors.blueGrey.shade600,
                  title: 'Profile',
                  subtitle: 'Manage account profile information',
                  onTap: () => context.pushRoute(const PersonalInformationRoute()),
                ),
                const SettingsSectionHeader(title: 'App & System'),
                SettingsCardTile(
                  leadingIcon: LucideIcons.settings,
                  iconColor: Colors.blueGrey.shade700,
                  title: 'App Settings',
                  subtitle: 'Manage app theme, preferences, and details',
                  onTap: () => context.pushRoute(const AppSettingsRoute()),
                ),
                SettingsCardTile(
                  leadingIcon: LucideIcons.logOut,
                  iconColor: Colors.red.shade600,
                  title: 'Sign Out',
                  subtitle: 'Logout from your account safely',
                  onTap: () => _signOut(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class StoreHeroCard extends StatelessWidget {
  const StoreHeroCard({super.key, this.store});
  final Store? store;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeName = store?.name ?? 'Afriomarkets';
    final initials = storeName.isNotEmpty ? storeName.substring(0, storeName.length >= 2 ? 2 : 1).toUpperCase() : 'AM';
    final defaultCurrency = store?.supportedCurrencies
            ?.firstWhere((c) => c.isDefault, orElse: () => const StoreCurrency(id: '', currencyCode: 'USD', storeId: '', isDefault: true, currency: Currency(code: 'USD', symbol: '\$', symbolNative: '\$', name: 'US Dollar')))
            .currencyCode
            .toUpperCase() ??
        'USD';

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B2B0C), const Color(0xFF11170C)]
              : [const Color(0xFF344F16), const Color(0xFFE48629)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF344F16).withOpacity(isDark ? 0.3 : 0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4.0),
                const Text(
                  'Store Management Settings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4.0),
                Text(
                  defaultCurrency,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
    required this.title,
    required this.leadingIcon,
    required this.iconColor,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
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
                    color: iconColor.withOpacity(0.12),
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
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                            ),
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
