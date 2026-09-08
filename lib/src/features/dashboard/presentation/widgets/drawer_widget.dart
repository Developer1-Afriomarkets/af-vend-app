import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:medusa_admin/src/core/constants/strings.dart';
import 'package:medusa_admin/src/core/extensions/snack_bar_extension.dart';
import 'package:medusa_admin/src/core/extensions/theme_mode_extension.dart';
import 'package:medusa_admin/src/core/utils/easy_loading.dart';
import 'package:medusa_admin/src/core/utils/medusa_icons_icons.dart';
import 'package:medusa_admin/src/features/app_settings/data/service/preference_service.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/features/app_settings/presentation/bloc/app_update/app_update_bloc.dart';
import 'package:medusa_admin/src/features/app_settings/presentation/cubits/theme/theme_cubit.dart';
import 'package:medusa_admin/src/features/auth/data/service/auth_preference_service.dart';
import 'package:medusa_admin/src/features/auth/presentation/bloc/authentication/authentication_bloc.dart';
import 'package:medusa_admin/src/features/store_details/presentation/bloc/store/store_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    int getRouteIndex(PageRouteInfo route) {
      if (route is DashboardOverviewRoute) return 0;
      if (route is OrdersRoute) return 1;
      if (route is DraftOrdersRoute) return 2;
      if (route is ProductsRoute) return 3;
      if (route is CollectionsRoute) return 4;
      if (route is CategoriesRoute) return 5;
      if (route is InventoryRoute) return 6;
      if (route is ReservationsRoute) return 7;
      if (route is CustomersRoute) return 8;
      if (route is GroupsRoute) return 9;
      if (route is PromotionsRoute) return 10;
      if (route is CampaignsRoute) return 11;
      if (route is PricingRoute) return 12;
      if (route is StoreSettingsRoute) return 13;
      if (route is AppSettingsRoute) return 14;
      if (route is PickupRequestsRoute) return 15;
      if (route is DeliveriesRoute) return 16;
      return 0;
    }

    final packageInfo = PreferenceService.packageInfo;
    String appName = packageInfo.appName;
    String version = packageInfo.version;

    final destinations = [
      DrawerDestination(
        icon: const Icon(CupertinoIcons.graph_square),
        label: 'Dashboard',
        route: const DashboardOverviewRoute(),
      ),
      DrawerDestination(
        icon: const Icon(CupertinoIcons.cart),
        label: 'Orders',
        route: const OrdersRoute(),
      ),
      const DrawerDestination.divider(),
      DrawerDestination(
        icon: const Icon(MedusaIcons.tag),
        label: 'Products',
        route: const ProductsRoute(),
      ),
      const DrawerDestination.divider(),
      DrawerDestination(
        icon: const Icon(Icons.discount_outlined),
        label: 'Promotions',
        route: const PromotionsRoute(),
      ),
      const DrawerDestination.divider(),
      DrawerDestination(
        icon: const Icon(CupertinoIcons.cube_box),
        label: 'Pickup Requests',
        route: PickupRequestsRoute(),
      ),
      DrawerDestination(
        icon: const Icon(Icons.local_shipping),
        label: 'Deliveries',
        route: DeliveriesRoute(),
      ),
      const DrawerDestination.divider(),
      DrawerDestination(
        icon: const Icon(Icons.settings_applications),
        label: 'Store Settings',
        route: const StoreSettingsRoute(),
      ),
      DrawerDestination(
        icon: const Icon(CupertinoIcons.settings),
        label: 'App Settings',
        route: const AppSettingsRoute(),
      ),
      DrawerDestination(
        icon: const Icon(Icons.logout, color: Colors.red),
        label: 'Sign Out',
        onTap: () => _signOut(context),
      ),
    ];

    Widget _divider() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                const Color(0xFFE48629).withOpacity(0.3),
                Colors.transparent,
              ]),
            ),
          ),
        );

    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        state.mapOrNull(
          loading: (_) => loading(),
          loggedOut: (_) async {
            await AuthPreferenceService.instance.clearLoginData();
            await AuthPreferenceService.instance.clearExportFiles();
            await AuthPreferenceService.instance.clearLoginKey();
            await dismissLoading();
            if (context.mounted) {
              context.router.replaceAll([SplashRoute(fromLogout: true)]);
            }
          },
          error: (e) {
            dismissLoading();
            context.showSnackBar(e.error.toSnackBarString());
          },
        );
      },
      child: Drawer(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF131A0B), // Deep dark olive/earth-black
                Color(0xFF1F2B0E), // Forest green midpoint
                Color(0xFF161F0A), // Rich olive
              ],
            ),
          ),
          child: Column(
            children: [
              // Header
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    children: [
                      BlocBuilder<ThemeCubit, ThemeState>(
                        builder: (context, state) {
                          return IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE48629).withOpacity(0.15),
                              foregroundColor: const Color(0xFFE48629),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            onPressed: () => context
                                .read<ThemeCubit>()
                                .updateThemeState(themeMode: state.themeMode.next),
                            icon: Icon(state.themeMode.icon),
                          );
                        },
                      ),
                      const Gap(8.0),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () {},
                            child: Ink(
                              height: 56,
                              decoration: ShapeDecoration(
                                shape: const StadiumBorder(),
                                color: const Color(0xFFF0EAD6).withOpacity(0.08),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  BlocBuilder<StoreBloc, StoreState>(
                                    builder: (context, state) {
                                      final storeName = state.mapOrNull(
                                          stores: (r) => r.response.stores.firstOrNull?.name);
                                      return Flexible(
                                        child: Text(
                                          storeName ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFFF0EAD6)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              BlocBuilder<AppUpdateBloc, AppUpdateState>(
                builder: (context, state) {
                  return state.maybeWhen(
                      updateAvailable: (appUpdate) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
                            child: Stack(
                              children: [
                                Container(
                                  height: 56,
                                  width: double.infinity,
                                  decoration: const ShapeDecoration(
                                    shape: StadiumBorder(),
                                    color: Colors.blue,
                                  ),
                                )
                                    .animate(
                                        autoPlay: true,
                                        onPlay: (controller) => controller.repeat(reverse: true))
                                    .shimmer(
                                        duration: const Duration(seconds: 5),
                                        blendMode: BlendMode.srcIn,
                                        colors: [Colors.blue, Colors.green, Colors.teal]),
                                Material(
                                  color: Colors.transparent,
                                  shape: const StadiumBorder(),
                                  child: InkWell(
                                    customBorder: const StadiumBorder(),
                                    onTap: () => context.pushRoute(const AppUpdateRoute()),
                                    child: Ink(
                                      height: 56,
                                      decoration: const ShapeDecoration(
                                        shape: StadiumBorder(),
                                      ),
                                      child: Row(
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.fromLTRB(16, 16, 10, 16),
                                            child: Icon(Icons.update, color: Colors.white),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text('New Update Available ${appUpdate.tagName ?? ''}',
                                                  style: const TextStyle(color: Colors.white)),
                                              Text('Tap to install',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      orElse: () => const SizedBox.shrink());
                },
              ),
              const Gap(10),
              // Destinations Scrollable View
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...destinations.map((e) {
                      if (e.isDivider) {
                        return _divider();
                      }
                      final isSelected = () {
                        final activeRouteName = context.tabsRouter.current.name;
                        return e.route?.routeName == activeRouteName;
                      }();
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
                        child: InkWell(
                          onTap: () {
                            if (e.onTap != null) {
                              e.onTap!();
                              return;
                            }
                            if (e.route != null) {
                              context.closeDrawer();
                              final routeIndex = getRouteIndex(e.route!);
                              context.tabsRouter.setActiveIndex(routeIndex);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          splashColor: const Color(0xFFE48629).withOpacity(0.15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE48629).withOpacity(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected ? Border.all(color: const Color(0xFFE48629).withOpacity(0.35), width: 1.0) : null,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                Theme(
                                  data: ThemeData(iconTheme: IconThemeData(color: isSelected ? const Color(0xFFE48629) : const Color(0xFFF0EAD6).withOpacity(0.7))),
                                  child: e.icon!,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    e.label!,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFFF0EAD6).withOpacity(0.85),
                                      fontSize: 14.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => _showAppAboutDialog(context),
                        onLongPress: () => context.pushRoute(const AppDevSettingsRoute()),
                        child: Ink(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: ShapeDecoration(
                            shape: const StadiumBorder(),
                            color: const Color(0xFFF0EAD6).withOpacity(0.08),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      'assets/images/app_logo.png',
                                      height: 32,
                                      width: 32,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const Gap(10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        appName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Version $version',
                                        style: TextStyle(
                                          color: const Color(0xFFF0EAD6).withOpacity(0.6),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Icon(Icons.info_outline, color: Color(0xFFF0EAD6)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class DrawerDestination {
  const DrawerDestination({
    this.icon,
    this.label,
    this.route,
    this.onTap,
    this.isDivider = false,
  });

  const DrawerDestination.divider()
      : icon = null,
        label = null,
        route = null,
        onTap = null,
        isDivider = true;

  final Widget? icon;
  final String? label;
  final PageRouteInfo? route;
  final void Function()? onTap;
  final bool isDivider;
}

void _showAppAboutDialog(BuildContext context, [bool useRootNavigator = true]) {
  final ThemeData theme = Theme.of(context);
  final TextStyle footerStyle = theme.textTheme.bodySmall!;

  final Size mediaSize = MediaQuery.sizeOf(context);
  final double width = mediaSize.width;
  final double height = mediaSize.height;

  showAboutDialog(
    context: context,
    applicationName: AppConstants.appName,
    applicationVersion: PreferenceService.packageInfo.version,
    useRootNavigator: useRootNavigator,
    applicationIcon: ClipOval(
      child: Image.asset(
        'assets/images/app_logo.png',
        height: 80,
        width: 80,
        fit: BoxFit.contain,
      ),
    ),
    applicationLegalese:
        '${AppConstants.copyright}  \n${AppConstants.author} \n${AppConstants.license}',
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                style: footerStyle,
                text: 'Built with Flutter'
                    '\nMedia size (w:${width.toStringAsFixed(0)}'
                    'h:${height.toStringAsFixed(0)})',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
