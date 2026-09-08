import 'package:dio/dio.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/extensions/medusa_model_extension.dart';
import 'package:medusa_admin/src/core/extensions/num_extension.dart';
import 'package:medusa_admin/src/core/extensions/date_time_extension.dart';
import 'package:medusa_admin/src/features/orders/presentation/bloc/orders/orders_bloc.dart';
import 'package:medusa_admin/src/features/products/presentation/bloc/product_crud/product_crud_bloc.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/features/dashboard/presentation/widgets/drawer_widget.dart';
import 'package:medusa_admin/src/features/store_details/presentation/bloc/store/store_bloc.dart';
import 'package:medusa_admin/src/core/di/di.dart';

String _formatCurrency(String? code) {
  if (code == null) return '₦';
  switch (code.toUpperCase()) {
    case 'NGN': return '₦';
    case 'USD': return r'$';
    case 'EUR': return '€';
    case 'GBP': return '£';
    case 'GHS': return 'GH₵';
    case 'CAD': return r'CA$';
    case 'AUD': return r'AU$';
    default: return '${code.toUpperCase()} ';
  }
}

@RoutePage()
class DashboardOverviewView extends StatefulWidget {
  const DashboardOverviewView({super.key});

  @override
  State<DashboardOverviewView> createState() => _DashboardOverviewViewState();
}

class _DashboardOverviewViewState extends State<DashboardOverviewView> {
  late final OrdersBloc _ordersBloc;
  late final ProductCrudBloc _productsBloc;
  Map<String, dynamic>? _walletData;
  Map<String, dynamic>? _bankAccount;

  @override
  void initState() {
    super.initState();
    _ordersBloc = OrdersBloc.instance..add(const OrdersEvent.loadOrders(queryParameters: {'limit': 50}));
    _productsBloc = ProductCrudBloc.instance..add(const ProductCrudEvent.loadAll(queryParameters: {'limit': 50}));
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      final dio = getIt<Dio>();
      final res = await dio.get('/admin/vendor/wallet');
      if (res.statusCode == 200 && res.data != null && mounted) {
        final data = res.data as Map<String, dynamic>;
        setState(() {
          _walletData = (data['wallet'] as Map<String, dynamic>?) ?? data;
          _bankAccount = (data['bankAccount'] as Map<String, dynamic>?) ?? (data['bank_account'] as Map<String, dynamic>?);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return MultiBlocProvider(
      providers: [
        BlocProvider<OrdersBloc>.value(value: _ordersBloc),
        BlocProvider<ProductCrudBloc>.value(value: _productsBloc),
      ],
      child: Scaffold(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        drawer: null,
        appBar: AppBar(
          title: BlocBuilder<StoreBloc, StoreState>(
            builder: (context, state) {
              final storeName = state.mapOrNull(
                stores: (r) => r.response.stores.firstOrNull?.name,
              );
              return Text(
                storeName != null ? '$storeName Overview' : 'Store Overview',
                style: GoogleFonts.comfortaa(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              );
            },
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: const Color(0xFF344F16),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () => context.pushRoute(const StoreSettingsRoute()),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _loadWalletData(),
              Future.sync(() {
                _ordersBloc.add(const OrdersEvent.loadOrders(queryParameters: {'limit': 50}));
                _productsBloc.add(const ProductCrudEvent.loadAll(queryParameters: {'limit': 50}));
              }),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Premium Greeting Banner
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1B3A0A),
                        Color(0xFF2A5C13),
                        Color(0xFFB86A10),
                      ],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Gold shimmer ring top-right
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE48629).withOpacity(0.22),
                              width: 28,
                            ),
                          ),
                        ),
                      ),
                      // Kente pattern overlay
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.10,
                          child: CustomPaint(
                            painter: _KentePainter(
                              baseColor: const Color(0xFFF8B55B),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE48629).withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE48629).withOpacity(0.5),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    color: Color(0xFFF8B55B),
                                    size: 20,
                                  ),
                                ),
                                const Gap(12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome Back, Vendor!',
                                      style: GoogleFonts.comfortaa(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Here\'s your store overview',
                                      style: GoogleFonts.comfortaa(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Gap(16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle, color: Color(0xFF5DDE8A), size: 8),
                                  const Gap(6),
                                  Text(
                                    'Store is Live',
                                    style: GoogleFonts.comfortaa(
                                      color: Colors.white.withOpacity(0.88),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BlocBuilder<OrdersBloc, OrdersState>(
                    builder: (context, ordersState) {
                      return BlocBuilder<ProductCrudBloc, ProductCrudState>(
                        builder: (context, productsState) {
                          // Extract orders & products count
                          final List<Order> loadedOrders = ordersState.maybeWhen(
                            orders: (orders, _) => orders,
                            orElse: () => [],
                          );
                          final int ordersCount = ordersState.maybeWhen(
                            orders: (_, count) => count,
                            orElse: () => 0,
                          );
                          final int productsCount = productsState.maybeWhen(
                            products: (_, count) => count,
                            orElse: () => 0,
                          );

                          // Get store default currency from StoreBloc
                          final storeState = context.read<StoreBloc>().state;
                          final String storeCurrency = storeState.mapOrNull(
                            stores: (r) => r.response.stores.firstOrNull?.supportedCurrencies
                                ?.where((sc) => sc.isDefault == true)
                                .map((sc) => sc.currencyCode)
                                .firstOrNull
                                ?? r.response.stores.firstOrNull?.supportedCurrencies?.firstOrNull?.currencyCode,
                          ) ?? 'usd';

                          // Calculate metrics
                          double revenue = 0;
                          int pendingFulfillments = 0;
                          for (final o in loadedOrders) {
                            revenue += o.totalValue.toDouble();
                            if (o.fulfillmentStatus == FulfillmentStatus.notFulfilled) {
                              pendingFulfillments++;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Vendor Wallet & Payout Banner
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => context.pushRoute(const VendorWalletRoute()),
                                  borderRadius: BorderRadius.circular(16.0),
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 16.0),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2C3E1B), Color(0xFF1B2C10)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(
                                        color: const Color(0xFFE48629).withOpacity(0.25),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          right: -10,
                                          bottom: -10,
                                          child: Icon(
                                            CupertinoIcons.creditcard_fill,
                                            size: 90,
                                            color: Colors.white.withOpacity(0.04),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'AFRIOMARKETS VENDOR WALLET',
                                                    style: GoogleFonts.comfortaa(
                                                      color: const Color(0xFFF8B55B),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE48629).withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'Tap to Manage ➔',
                                                      style: GoogleFonts.comfortaa(
                                                        color: const Color(0xFFF8B55B),
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Gap(10),
                                              Builder(
                                                builder: (context) {
                                                  final totalBalanceMap = (_walletData?['total_balance'] as Map<String, dynamic>?) ?? {};
                                                  final primaryCurrency = totalBalanceMap.containsKey('NGN')
                                                      ? 'NGN'
                                                      : (totalBalanceMap.keys.firstOrNull ?? storeCurrency.toUpperCase());
                                                  final primaryBalance = totalBalanceMap[primaryCurrency] ?? (revenue * 0.85);
                                                  final otherCurrencies = totalBalanceMap.keys.where((c) => c != primaryCurrency).toList();

                                                  return Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${_formatCurrency(primaryCurrency)}${primaryBalance is num ? primaryBalance.toStringAsFixed(2) : primaryBalance.toString()} $primaryCurrency',
                                                        style: GoogleFonts.comfortaa(
                                                          color: Colors.white,
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      if (otherCurrencies.isNotEmpty) ...[
                                                        const Gap(6),
                                                        Wrap(
                                                          spacing: 6,
                                                          runSpacing: 4,
                                                          children: otherCurrencies.map((c) {
                                                            final amt = totalBalanceMap[c] ?? 0;
                                                            return Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white.withOpacity(0.14),
                                                                borderRadius: BorderRadius.circular(8),
                                                                border: Border.all(color: Colors.white24, width: 0.8),
                                                              ),
                                                              child: Text(
                                                                '${_formatCurrency(c)}$amt $c',
                                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ],
                                                    ],
                                                  );
                                                },
                                              ),
                                              const Gap(2),
                                              Text(
                                                _bankAccount != null
                                                    ? 'Payout Destination: ${_bankAccount!['bank_name'] ?? ''} (${_bankAccount!['account_number'] ?? ''})'
                                                    : 'Available Balance • Tap to setup bank account',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.65),
                                                  fontSize: 10,
                                                ),
                                              ),
                                              const Gap(12),
                                              const Divider(color: Colors.white10, height: 1),
                                              const Gap(12),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Settlement Mode',
                                                        style: TextStyle(
                                                          color: Colors.white.withOpacity(0.4),
                                                          fontSize: 8.5,
                                                        ),
                                                      ),
                                                      const Gap(2),
                                                      Text(
                                                        _bankAccount != null ? 'Automated & On-Demand' : 'Pending Bank Setup',
                                                        style: TextStyle(
                                                          color: Colors.white.withOpacity(0.85),
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => context.pushRoute(const VendorWalletRoute()),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFE48629),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                      minimumSize: Size.zero,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: Text(
                                                      'Request Payout',
                                                      style: GoogleFonts.comfortaa(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // 2. Metrics Grid
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.4,
                                children: [
                                  _buildMetricCard(
                                    title: 'Total Revenue',
                                    value: revenue.formatAsPrice(storeCurrency),
                                    icon: CupertinoIcons.money_dollar_circle_fill,
                                    accentColor: const Color(0xFF048630), // Market green
                                    isDark: isDark,
                                  ),
                                  _buildMetricCard(
                                    title: 'Total Orders',
                                    value: '$ordersCount',
                                    icon: CupertinoIcons.cart_fill,
                                    accentColor: const Color(0xFFE48629), // Orange
                                    isDark: isDark,
                                  ),
                                  _buildMetricCard(
                                    title: 'Active Products',
                                    value: '$productsCount',
                                    icon: CupertinoIcons.cube_box_fill,
                                    accentColor: const Color(0xFF3D8B7A), // Teal
                                    isDark: isDark,
                                  ),
                                  _buildMetricCard(
                                    title: 'Unfulfilled Orders',
                                    value: '$pendingFulfillments',
                                    icon: CupertinoIcons.clock_fill,
                                    accentColor: const Color(0xFF861B04), // Market red
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                              const Gap(20),
                              Text(
                                'Quick Actions',
                                style: GoogleFonts.comfortaa(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
                                ),
                              ),
                              const Gap(12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildQuickActionBtn(
                                      label: 'Vendor Wallet',
                                      icon: Icons.account_balance_wallet_outlined,
                                      color: const Color(0xFF2C3E1B),
                                      onTap: () => context.pushRoute(const VendorWalletRoute()),
                                    ),
                                    const Gap(12),
                                    _buildQuickActionBtn(
                                      label: 'Add Product',
                                      icon: Icons.add_photo_alternate_outlined,
                                      color: const Color(0xFFE48629),
                                      onTap: () => context.pushRoute(AddUpdateProductRoute()),
                                    ),
                                    const Gap(12),
                                    _buildQuickActionBtn(
                                      label: 'New Pickup',
                                      icon: CupertinoIcons.cube_box,
                                      color: const Color(0xFF344F16),
                                      onTap: () => context.pushRoute(AddUpdatePickupRequestRoute()),
                                    ),
                                    const Gap(12),
                                    _buildQuickActionBtn(
                                      label: 'New Delivery',
                                      icon: Icons.local_shipping_outlined,
                                      color: Colors.blue.shade600,
                                      onTap: () => context.pushRoute(AddUpdateDeliveryRoute()),
                                    ),
                                  ],
                                ),
                              ),

                              const Gap(24),

                              // 3. Weekly Sales Performance Graph Card
                              _buildChartSection(revenue, loadedOrders, isDark),

                              const Gap(24),

                              // 4. Recent Orders Row
                              Text(
                                'Recent Orders',
                                style: GoogleFonts.comfortaa(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
                                ),
                              ),
                              const Gap(10),
                              if (loadedOrders.isEmpty)
                                Card(
                                  elevation: 0.5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: context.theme.dividerColor.withOpacity(0.4)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Center(
                                      child: Text(
                                        'No recent orders available.',
                                        style: TextStyle(color: context.theme.disabledColor),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: loadedOrders.take(5).length,
                                  separatorBuilder: (_, __) => const Gap(8),
                                  itemBuilder: (context, index) {
                                    final o = loadedOrders[index];
                                    return _buildOrderListItem(o, context);
                                  },
                                ),

                              const Gap(24),

                              // 5. Stock Level Alerts
                              _buildStockAlertsSection(productsState, isDark),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDark;
    return Container(
      width: 140,
      height: 90,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 18,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.comfortaa(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1800) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2800) : const Color(0xFFE8E2D6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.comfortaa(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8A7D60) : Colors.grey.shade600,
                ),
              ),
              Icon(icon, color: accentColor.withOpacity(0.85), size: 20),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.comfortaa(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(double revenue, List<Order> orders, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1800) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2800) : const Color(0xFFE8E2D6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Sales Progression',
                    style: GoogleFonts.comfortaa(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
                    ),
                  ),
                  const Gap(4),
                  Text(
                    'Sales trend for the last loaded orders',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF8A7D60) : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF048630).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Live',
                  style: GoogleFonts.comfortaa(
                    color: const Color(0xFF048630),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Gap(24),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _SalesChartPainter(
                orders: orders,
                lineColor: const Color(0xFFE48629),
                fillColor: const Color(0xFFE48629).withOpacity(0.08),
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListItem(Order order, BuildContext context) {
    final isDark = context.isDark;
    String status = order.paymentStatus?.name.toUpperCase() ?? 'PENDING';
    Color statusColor = const Color(0xFFE48629); // Orange / Pending
    if (order.paymentStatus == PaymentStatus.captured) {
      statusColor = const Color(0xFF048630); // Green
    } else if (order.paymentStatus == PaymentStatus.refunded) {
      statusColor = const Color(0xFF3D8B7A); // Teal
    }

    return GestureDetector(
      onTap: () => context.pushRoute(OrderDetailsRoute(orderId: order.id)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1800) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2E2800) : const Color(0xFFE8E2D6),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.displayId}',
                  style: GoogleFonts.comfortaa(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
                  ),
                ),
                const Gap(4),
                Text(
                  order.createdAt?.formatDate() ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF8A7D60) : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.comfortaa(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Gap(12),
                Text(
                  order.totalValue.toDouble().formatAsPrice(order.currencyCode),
                  style: GoogleFonts.comfortaa(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockAlertsSection(ProductCrudState productsState, bool isDark) {
    final List<Product> loadedProducts = productsState.maybeWhen(
      products: (products, _) => products,
      orElse: () => [],
    );

    // Filter low stock variants
    final List<Map<String, dynamic>> lowStockVariants = [];
    for (final p in loadedProducts) {
      if (p.variants != null) {
        for (final v in p.variants!) {
          final int stock = v.inventoryQuantity ?? 0;
          if (stock <= 5) {
            lowStockVariants.add({
              'productName': p.title,
              'variantName': v.title,
              'stock': stock,
            });
          }
        }
      }
    }

    if (lowStockVariants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(24),
        Text(
          'Inventory & Stock Alerts',
          style: GoogleFonts.comfortaa(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
          ),
        ),
        const Gap(10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lowStockVariants.take(3).length,
          separatorBuilder: (_, __) => const Gap(8),
          itemBuilder: (context, index) {
            final alert = lowStockVariants[index];
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1800) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF861B04).withOpacity(0.3),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['productName'] ?? '',
                          style: GoogleFonts.comfortaa(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? const Color(0xFFF0EAD6) : const Color(0xFF1A1400),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(4),
                        Text(
                          'Variant: ${alert['variantName']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF8A7D60) : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF861B04).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${alert['stock']} Left',
                      style: GoogleFonts.comfortaa(
                        color: const Color(0xFF861B04),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// African-inspired kente arc background silhouettes painter
class _KentePainter extends CustomPainter {
  final Color baseColor;
  _KentePainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = baseColor.withOpacity(0.08)
      ..strokeWidth = 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.9, size.height * 1.1), radius: size.width * 0.5),
      3.14,
      1.5,
      false,
      stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.1, -size.height * 0.2), radius: size.width * 0.4),
      0,
      1.5,
      false,
      stroke,
    );

    // Subtle horizontal kente stripes
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor.withOpacity(0.05);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.75, size.width, 4), fill);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.85, size.width, 2), fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for Weekly Sales progression curve
class _SalesChartPainter extends CustomPainter {
  final List<Order> orders;
  final Color lineColor;
  final Color fillColor;
  final bool isDark;

  _SalesChartPainter({
    required this.orders,
    required this.lineColor,
    required this.fillColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (orders.isEmpty) {
      _paintEmptyState(canvas, size);
      return;
    }

    final List<double> values = orders.map((o) => o.totalValue.toDouble()).toList().reversed.toList();
    
    // Normalize values
    double maxVal = values.fold(0.0, (max, val) => val > max ? val : max);
    if (maxVal == 0) maxVal = 1;

    final double widthStep = size.width / (values.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < values.length; i++) {
      final double x = i * widthStep;
      final double y = size.height - (values[i] / maxVal * (size.height - 20)) - 10;
      points.add(Offset(x, y));
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF2E2800).withOpacity(0.3) : Colors.grey.shade200
      ..strokeWidth = 1.0;
    
    for (double i = 0; i <= size.height; i += size.height / 3) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Path for line and area fill
    final linePath = Path();
    final fillPath = Path();

    linePath.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      // Curve connection
      final xc = (points[i - 1].dx + points[i].dx) / 2;
      final yc = (points[i - 1].dy + points[i].dy) / 2;
      linePath.quadraticBezierTo(points[i - 1].dx, points[i - 1].dy, xc, yc);
      fillPath.quadraticBezierTo(points[i - 1].dx, points[i - 1].dy, xc, yc);
    }
    
    linePath.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill area
    final areaPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawPath(fillPath, areaPaint);

    // Draw progression line
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = lineColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw indicator dots for start and end
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = lineColor;
    canvas.drawCircle(points.first, 4.0, dotPaint);
    canvas.drawCircle(points.last, 6.0, dotPaint);

    // Draw pulse halo on final point
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = lineColor.withOpacity(0.3)
      ..strokeWidth = 2.0;
    canvas.drawCircle(points.last, 10.0, haloPaint);
  }

  void _paintEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Waiting for orders data...',
        style: TextStyle(
          color: isDark ? const Color(0xFF8A7D60) : Colors.grey.shade400,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) => true;
}
