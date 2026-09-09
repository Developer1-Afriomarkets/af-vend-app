import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/features/pickup_requests/presentation/screens/pickup_requests_view.dart';
import 'package:medusa_admin/src/features/deliveries/presentation/screens/deliveries_view.dart';

@RoutePage()
class PickupRequestsDeliveriesView extends StatelessWidget {
  const PickupRequestsDeliveriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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
          title: Text(
            'Logistics',
            style: GoogleFonts.comfortaa(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: const Color(0xFF344F16),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56.0),
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  color: const Color(0xFFE48629),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE48629).withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.0,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.0,
                  letterSpacing: -0.2,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Pickup Requests'),
                  Tab(text: 'Deliveries'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            PickupRequestsView(isNested: true),
            DeliveriesView(isNested: true),
          ],
        ),
      ),
    );
  }
}
