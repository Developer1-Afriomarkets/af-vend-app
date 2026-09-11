import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:medusa_admin/src/core/extensions/medusa_model_extension.dart';
import 'package:gap/gap.dart';
import 'package:medusa_admin/src/core/constants/colors.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

class OrderLogisticsActions extends StatelessWidget {
  const OrderLogisticsActions({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final regionName = order.regionName;
    final regionId = order.regionId;

    return Container(
      decoration: BoxDecoration(
        color: context.theme.cardColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0xFFE48629).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: const Color(0xFFE48629).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15.0),
                topRight: Radius.circular(15.0),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFE48629),
                  child: Icon(Icons.local_shipping, size: 16, color: Colors.white),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logistics & Delivery Dispatch',
                        style: context.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B3A0A),
                        ),
                      ),
                      Text(
                        'Region: $regionName',
                        style: context.bodySmall?.copyWith(
                          color: ColorManager.manatee,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3A0A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Afrio Hub',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B3A0A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                Row(
                  children: [
                    // 1-Tap Request Hub Pickup
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B3A0A),
                          side: const BorderSide(color: Color(0xFF1B3A0A), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          context.pushRoute(
                            AddUpdatePickupRequestRoute(
                              preselectedOrderId: order.id,
                              preselectedRegionId: regionId,
                            ),
                          );
                        },
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: const Text('Request Pickup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const Gap(10),

                    // 1-Tap Dispatch Direct Delivery
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE48629),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          context.pushRoute(
                            AddUpdateDeliveryRoute(
                              preselectedOrderId: order.id,
                              preselectedRegionId: regionId,
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Direct Dispatch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  'Route package via collection station or dispatch directly to customer doorstep.',
                  style: context.bodySmall?.copyWith(color: ColorManager.manatee, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
