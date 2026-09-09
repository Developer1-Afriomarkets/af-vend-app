import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
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
      child: AutoTabsRouter(
        homeIndex: 0,
        routes: const [
          DashboardOverviewRoute(),
          OrdersRoute(),
          PickupRequestsDeliveriesRoute(),
          ProductsRoute(),
          StoreSettingsRoute(),
        ],
        transitionBuilder: (context, child, animation) => child,
        builder: (context, child) {
          final tabsRouter = AutoTabsRouter.of(context);
          
          Widget buildTabItem({
            required int index,
            required IconData icon,
            required String label,
          }) {
            final isSelected = tabsRouter.activeIndex == index;
            final color = isSelected ? const Color(0xFFE48629) : Colors.grey.shade500;
            
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
                        style: TextStyle(
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

          return Scaffold(
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
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border: Border.all(
                    color: context.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    buildTabItem(index: 0, icon: Icons.dashboard_outlined, label: 'Dashboard'),
                    buildTabItem(index: 1, icon: Icons.shopping_bag_outlined, label: 'Orders'),
                    
                    // Center elevated Logistics button
                    Container(
                      transform: Matrix4.translationValues(0, -12, 0),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
                            ? const Color(0xFFE48629)
                            : const Color(0xFF344F16),
                        elevation: 3,
                        shape: const CircleBorder(),
                        tooltip: 'Logistics',
                        child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24),
                      ),
                    ),

                    buildTabItem(index: 3, icon: Icons.sell_outlined, label: 'Products'),
                    buildTabItem(index: 4, icon: Icons.settings_outlined, label: 'Settings'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
