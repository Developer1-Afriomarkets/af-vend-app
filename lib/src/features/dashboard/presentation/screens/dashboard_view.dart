import 'package:medusa_admin/src/features/dashboard/presentation/widgets/drawer_widget.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';
import 'package:medusa_admin/src/features/orders/presentation/bloc/orders/orders_bloc.dart';
import 'package:medusa_admin/src/features/orders/presentation/bloc/orders_filter/orders_filter_bloc.dart';
import 'package:medusa_admin/src/features/products/presentation/cubits/products_filter/products_filter_cubit.dart';

@RoutePage()
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<OrdersBloc>(
          create: (_) => OrdersBloc.instance,
        ),
        BlocProvider<OrdersFilterBloc>(
          create: (_) => OrdersFilterBloc.instance,
        ),
        BlocProvider<ProductsFilterCubit>(
          create: (_) => ProductsFilterCubit.instance,
        ),
      ],
      child: ValueListenableBuilder<AppScope>(
        valueListenable: AppScopeService.activeScopeNotifier,
        builder: (context, activeScope, _) {
          final List<PageRouteInfo> routes;
          switch (activeScope) {
            case AppScope.logistics:
              routes = [
                const DashboardOverviewRoute(),
                PickupRequestsRoute(),
                DeliveriesRoute(),
                const PickupRequestsDeliveriesRoute(),
                const StoreSettingsRoute(),
              ];
              break;
            case AppScope.rider:
              routes = [
                const DashboardOverviewRoute(),
                DeliveriesRoute(),
                PickupRequestsRoute(),
                const PickupRequestsDeliveriesRoute(),
                const StoreSettingsRoute(),
              ];
              break;
            case AppScope.admin:
              routes = [
                const DashboardOverviewRoute(),
                const OrdersRoute(),
                DeliveriesRoute(),
                const ProductsRoute(),
                const StoreSettingsRoute(),
              ];
              break;
            case AppScope.vendor:
              routes = const [
                DashboardOverviewRoute(),
                OrdersRoute(),
                PickupRequestsDeliveriesRoute(),
                ProductsRoute(),
                StoreSettingsRoute(),
              ];
              break;
          }

          return AutoTabsRouter(
            key: ValueKey(activeScope),
            homeIndex: 0,
            routes: routes,
            transitionBuilder: (context, child, animation) => child,
            builder: (context, child) {
              final tabsRouter = AutoTabsRouter.of(context);
              final accent = activeScope.accentColor;

              Widget buildTabItem({
                required int index,
                required IconData icon,
                required String label,
              }) {
                final isSelected = tabsRouter.activeIndex == index;
                final color = isSelected ? accent : Colors.grey.shade500;

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => tabsRouter.setActiveIndex(index),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: color, size: 22),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: GoogleFonts.comfortaa(
                              color: color,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Dynamic role-specific navigation tab labels and icons
              final String tab1Label;
              final IconData tab1Icon;
              final String tab2Label;
              final IconData tab2Icon;
              final String centerTooltip;
              final IconData centerIcon;
              final String tab4Label;
              final IconData tab4Icon;
              final String tab5Label;
              final IconData tab5Icon;

              switch (activeScope) {
                case AppScope.logistics:
                  tab1Label = 'Ops Hub';
                  tab1Icon = Icons.hub_outlined;
                  tab2Label = 'Pickups';
                  tab2Icon = Icons.swap_vert_circle_outlined;
                  centerTooltip = 'Active Deliveries';
                  centerIcon = Icons.local_shipping_rounded;
                  tab4Label = 'Stations';
                  tab4Icon = Icons.alt_route_rounded;
                  tab5Label = 'Hub Settings';
                  tab5Icon = Icons.business_outlined;
                  break;
                case AppScope.rider:
                  tab1Label = 'Cockpit';
                  tab1Icon = Icons.speed_rounded;
                  tab2Label = 'My Runs';
                  tab2Icon = Icons.two_wheeler_rounded;
                  centerTooltip = 'Pickup Jobs';
                  centerIcon = Icons.qr_code_scanner_rounded;
                  tab4Label = 'Stations';
                  tab4Icon = Icons.location_on_outlined;
                  tab5Label = 'Profile';
                  tab5Icon = Icons.account_circle_outlined;
                  break;
                case AppScope.admin:
                  tab1Label = 'HQ';
                  tab1Icon = Icons.admin_panel_settings_outlined;
                  tab2Label = 'Orders';
                  tab2Icon = Icons.receipt_long_outlined;
                  centerTooltip = 'Global Deliveries';
                  centerIcon = Icons.local_shipping_rounded;
                  tab4Label = 'Catalog';
                  tab4Icon = Icons.store_mall_directory_outlined;
                  tab5Label = 'Settings';
                  tab5Icon = Icons.tune_rounded;
                  break;
                case AppScope.vendor:
                  tab1Label = 'Overview';
                  tab1Icon = Icons.dashboard_outlined;
                  tab2Label = 'Orders';
                  tab2Icon = Icons.shopping_bag_outlined;
                  centerTooltip = 'Logistics Grid';
                  centerIcon = Icons.local_shipping_rounded;
                  tab4Label = 'Products';
                  tab4Icon = Icons.sell_outlined;
                  tab5Label = 'Store';
                  tab5Icon = Icons.storefront_outlined;
                  break;
              }

              return Scaffold(
                drawer: const AppDrawer(),
                resizeToAvoidBottomInset: false,
                body: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: context.systemUiOverlayNoAppBarStyle,
                  child: child,
                ),
                bottomNavigationBar: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.theme.bottomNavigationBarTheme.backgroundColor ??
                          (context.isDark ? const Color(0xFF131A0B) : Colors.white),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                      border: Border.all(
                        color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        buildTabItem(index: 0, icon: tab1Icon, label: tab1Label),
                        buildTabItem(index: 1, icon: tab2Icon, label: tab2Label),

                        // Center elevated Action button
                        Container(
                          transform: Matrix4.translationValues(0, -12, 0),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: context.theme.scaffoldBackgroundColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4.0),
                          child: FloatingActionButton(
                            heroTag: 'nav_center_logistics_fab',
                            onPressed: () => tabsRouter.setActiveIndex(2),
                            backgroundColor: tabsRouter.activeIndex == 2
                                ? accent
                                : activeScope.color,
                            elevation: 3,
                            shape: const CircleBorder(),
                            tooltip: centerTooltip,
                            child: Icon(centerIcon, color: Colors.white, size: 24),
                          ),
                        ),

                        buildTabItem(index: 3, icon: tab4Icon, label: tab4Label),
                        buildTabItem(index: 4, icon: tab5Icon, label: tab5Label),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
