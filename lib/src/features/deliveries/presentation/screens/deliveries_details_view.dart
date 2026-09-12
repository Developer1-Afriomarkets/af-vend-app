import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:medusa_admin/src/core/constants/colors.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';
import 'package:medusa_admin/src/core/extensions/medusa_model_extension.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:medusa_admin/src/features/orders/domain/usecases/order/order_details_use_case.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';

@RoutePage()
class DeliveriesDetailsView extends StatefulWidget {
  const DeliveriesDetailsView({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  State<DeliveriesDetailsView> createState() => _DeliveriesDetailsViewState();
}

class _DeliveriesDetailsViewState extends State<DeliveriesDetailsView> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? delivery;
  Map<String, dynamic>? originStation;
  Map<String, dynamic>? destStation;
  Map<String, dynamic>? logisticsOrg;
  List<Order> orders = [];
  bool isLoading = true;
  bool isLoadingOrders = true;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchDeliveryDetails();
  }

  Future<void> _fetchDeliveryDetails() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('deliveries')
          .select('*')
          .eq('id', widget.deliveryId)
          .single();

      final regId = response['region_id']?.toString();
      if (regId != null && regId.isNotEmpty) {
        try {
          final regRes = await supabase
              .from('region')
              .select('name')
              .eq('id', regId)
              .maybeSingle();
          if (regRes != null) {
            response['resolved_region_name'] =
                regRes['name']?.toString() ?? 'N/A';
          }
        } catch (_) {}
      }

      // Fetch Origin Station
      final origId = response['origin_collection_station_id'];
      if (origId != null) {
        try {
          final sRes = await supabase
              .from('collection_stations')
              .select('*')
              .eq('id', origId)
              .maybeSingle();
          if (mounted) setState(() => originStation = sRes);
        } catch (_) {}
      }

      // Fetch Dest Station
      final destId = response['dest_collection_station_id'];
      if (destId != null) {
        try {
          final dRes = await supabase
              .from('collection_stations')
              .select('*')
              .eq('id', destId)
              .maybeSingle();
          if (mounted) setState(() => destStation = dRes);
        } catch (_) {}
      }

      // Fetch Logistics Org
      final orgId = response['logistics_org_id'];
      if (orgId != null) {
        try {
          final oRes = await supabase
              .from('logistics_orgs')
              .select('*')
              .eq('id', orgId)
              .maybeSingle();
          if (mounted) setState(() => logisticsOrg = oRes);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          delivery = response;
          isLoading = false;
        });
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingOrders = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load delivery details: $e')),
        );
      }
    }
  }

  List<String> _parseOrderIds(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String) {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        return raw
            .substring(1, raw.length - 1)
            .split(',')
            .map((s) => s.trim().replaceAll('"', ''))
            .where((s) => s.isNotEmpty)
            .toList();
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
      if (raw.trim().isNotEmpty) {
        return [raw.trim()];
      }
    }
    return [];
  }

  Future<void> _fetchOrders() async {
    final del = delivery;
    if (del == null) return;

    final orderIds = _parseOrderIds(del['order_ids']);
    if (orderIds.isEmpty) {
      setState(() => isLoadingOrders = false);
      return;
    }

    setState(() => isLoadingOrders = true);
    try {
      final fetchedOrders = <Order>[];
      for (final id in orderIds) {
        final result = await OrderCrudUseCase.instance.retrieveOrder(id: id);
        result.when(
          (order) => fetchedOrders.add(order),
          (error) => debugPrint('Error fetching order $id: $error'),
        );
      }
      if (mounted) {
        setState(() {
          orders = fetchedOrders;
          isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingOrders = false);
      }
    }
  }

  String _toDbStatus(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
      case 'in transit':
      case 'processing':
        return 'processing';
      case 'delivered':
        return 'delivered';
      case 'completed':
        return 'completed';
      case 'pending':
      case 'created':
      default:
        return 'created';
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final del = delivery;
    if (del == null) return;

    final dbStatus = _toDbStatus(newStatus);
    setState(() => isUpdating = true);
    try {
      await supabase
          .from('deliveries')
          .update({'status': dbStatus}).eq('id', del['id']);

      // Synchronize shipment status with Medusa if fulfillment_id is known
      if (dbStatus == 'in_transit' ||
          dbStatus == 'shipped' ||
          dbStatus == 'completed') {
        try {
          final rawMeta = del['metadata'];
          dynamic rawFul = (rawMeta is Map)
              ? (rawMeta['fulfillment_id'] ?? rawMeta['fulfillment_ids'])
              : null;
          String? fulId;
          if (rawFul is String) {
            fulId = rawFul;
          } else if (rawFul is List && rawFul.isNotEmpty) {
            fulId = rawFul.first.toString();
          }

          final rawOrders = del['order_ids'];
          String? ordId;
          if (rawOrders is List && rawOrders.isNotEmpty) {
            ordId = rawOrders.first.toString();
          }

          if (fulId != null && ordId != null) {
            await OrderCrudUseCase.instance.createShipment(
              id: ordId,
              fulfillmentId: fulId,
            );
          }
        } catch (e) {
          debugPrint('Medusa shipment sync notice: $e');
        }
      }

      setState(() {
        del['status'] = dbStatus;
        isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery marked as ${newStatus.toUpperCase()}'),
            backgroundColor: const Color(0xFF1B3A0A),
          ),
        );
      }
    } catch (e) {
      setState(() => isUpdating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _completeDeliveryWithProof() async {
    final recipientCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_outlined, color: Color(0xFF1B3A0A)),
            Gap(8),
            Text('Complete Delivery Run'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm receipt of package and record recipient confirmation details:',
              style: TextStyle(fontSize: 13),
            ),
            const Gap(12),
            TextField(
              controller: recipientCtrl,
              decoration: InputDecoration(
                labelText: 'Received By (Name / Staff ID)',
                hintText: 'e.g. Kwesi Mensah / Security Desk',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Gap(10),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Delivery Notes / Condition',
                hintText: 'e.g. Delivered intact in original packaging',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B3A0A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final del = delivery;
      if (del == null) return;

      setState(() => isUpdating = true);
      try {
        final Map<String, dynamic> updatePayload = {
          'status': 'completed',
        };
        await supabase
            .from('deliveries')
            .update(updatePayload)
            .eq('id', del['id']);

        setState(() {
          del['status'] = 'completed';
          isUpdating = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery successfully confirmed and completed!'),
              backgroundColor: Color(0xFF1B3A0A),
            ),
          );
        }
      } catch (e) {
        setState(() => isUpdating = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error completing delivery: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteDelivery() async {
    final del = delivery;
    if (del == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery'),
        content: const Text('Are you sure you want to delete this delivery?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isUpdating = true);
      try {
        await supabase.from('deliveries').delete().eq('id', del['id']);
        if (mounted) {
          context.maybePop(true);
        }
      } catch (e) {
        setState(() => isUpdating = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete delivery: $e')),
          );
        }
      }
    }
  }

  void _callNumber(String phone) async {
    if (phone.isEmpty || phone == 'N/A') return;
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _smsNumber(String phone) async {
    if (phone.isEmpty || phone == 'N/A') return;
    final Uri url = Uri.parse('sms:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildProcessTimeline(String currentStatus) {
    final steps = ['PENDING', 'ONGOING', 'COMPLETED'];
    final normalized = currentStatus.toUpperCase();
    int currentStepIndex = steps.indexOf(normalized);
    if (currentStepIndex < 0) currentStepIndex = 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.square_stack_3d_up,
                    size: 20, color: Color(0xFFE48629)),
                const Gap(8),
                Text(
                  'Delivery Lifecycle',
                  style:
                      context.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Gap(16),
            Row(
              children: List.generate(steps.length, (index) {
                final isPassed = index <= currentStepIndex;
                final isCurrent = index == currentStepIndex;
                final stepTitle =
                    steps[index] == 'ONGOING' ? 'IN TRANSIT' : steps[index];

                Color stepColor;
                if (isCurrent) {
                  stepColor = const Color(0xFFE48629);
                } else if (isPassed) {
                  stepColor = const Color(0xFF1B3A0A);
                } else {
                  stepColor = Colors.grey.shade400;
                }

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: stepColor.withValues(alpha: 0.15),
                                border: Border.all(color: stepColor, width: 2),
                              ),
                              child: Center(
                                child: isPassed && !isCurrent
                                    ? Icon(Icons.check,
                                        size: 16, color: stepColor)
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: stepColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const Gap(6),
                            Text(
                              stepTitle,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? stepColor
                                    : ColorManager.manatee,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: index < currentStepIndex
                                ? const Color(0xFF1B3A0A)
                                : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Details')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final del = delivery!;
    final manatee = ColorManager.manatee;
    final smallTextStyle = context.bodySmall;
    final status = del['status']?.toString().toUpperCase() ?? 'PENDING';
    final regionName = del['resolved_region_name']?.toString() ?? 'N/A';
    final driverName = del['driver_name']?.toString() ?? 'Unassigned';
    final driverPhone = del['driver_phone']?.toString() ?? 'N/A';
    final vehicleInfo = del['vehicle_info']?.toString() ?? 'N/A';
    final vehicleType = del['vehicle_type']?.toString() ?? 'Van';
    final deliveryMode = del['delivery_mode']?.toString() ?? 'Standard';
    final routeCategory =
        del['route_category']?.toString().replaceAll('_', ' ').toUpperCase() ??
            'INTRA STATE';

    DateTime? createdAt;
    if (del['created_at'] != null) {
      createdAt = DateTime.tryParse(del['created_at'].toString());
    }
    final dateString = createdAt != null
        ? DateFormat.yMMMd().add_jm().format(createdAt)
        : 'N/A';

    Color statusColor;
    if (status == 'COMPLETED' || status == 'DELIVERED') {
      statusColor = const Color(0xFF1B3A0A);
    } else if (status == 'ONGOING' ||
        status == 'PROCESSING' ||
        status == 'IN TRANSIT') {
      statusColor = Colors.blue.shade700;
    } else {
      statusColor = const Color(0xFFE48629);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.pencil_circle,
                color: Color(0xFFE48629)),
            tooltip: 'Edit Delivery',
            onPressed: () async {
              final updated = await context.pushRoute(
                AddUpdateDeliveryRoute(delivery: del),
              );
              if (updated == true) {
                _fetchDeliveryDetails();
              }
            },
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.trash, color: Colors.red),
            tooltip: 'Delete Delivery',
            onPressed: _deleteDelivery,
          ),
        ],
      ),
      body: SafeArea(
        child: isUpdating
            ? const Center(child: CircularProgressIndicator.adaptive())
            : RefreshIndicator(
                onRefresh: _fetchDeliveryDetails,
                child: ListView(
                  padding: const EdgeInsets.all(12.0),
                  children: [
                    // Status & Action Header Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Delivery Status',
                                        style: smallTextStyle?.copyWith(
                                            color: manatee)),
                                    const Gap(4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: statusColor.withValues(
                                                alpha: 0.5)),
                                      ),
                                      child: Text(
                                        status == 'ONGOING'
                                            ? 'IN TRANSIT'
                                            : status,
                                        style: context.bodyMedium?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                DropdownButtonHideUnderline(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: DropdownButton<String>(
                                      value: (status == 'CREATED' ||
                                              status == 'PENDING')
                                          ? 'Pending'
                                          : (status == 'PROCESSING' ||
                                                  status == 'ONGOING' ||
                                                  status == 'IN TRANSIT')
                                              ? 'Ongoing'
                                              : (status == 'DELIVERED')
                                                  ? 'Delivered'
                                                  : 'Completed',
                                      onChanged: (val) {
                                        if (val != null) _updateStatus(val);
                                      },
                                      items: [
                                        'Pending',
                                        'Ongoing',
                                        'Delivered',
                                        'Completed'
                                      ]
                                          .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s == 'Ongoing'
                                                  ? 'In Transit'
                                                  : s)))
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Quick Action Buttons
                            const Gap(14),
                            Row(
                              children: [
                                if (status == 'PENDING' || status == 'CREATED')
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFE48629),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () =>
                                          _updateStatus('processing'),
                                      icon: const Icon(Icons.play_arrow,
                                          size: 18),
                                      label:
                                          const Text('Dispatch / In Transit'),
                                    ),
                                  ),
                                if (status == 'ONGOING' ||
                                    status == 'PROCESSING' ||
                                    status == 'IN TRANSIT')
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1B3A0A),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: _completeDeliveryWithProof,
                                      icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 18),
                                      label: const Text('Confirm Delivered'),
                                    ),
                                  ),
                                if (status == 'COMPLETED' ||
                                    status == 'DELIVERED')
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF1B3A0A),
                                        side: const BorderSide(
                                            color: Color(0xFF1B3A0A)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () =>
                                          _updateStatus('processing'),
                                      icon: const Icon(Icons.undo, size: 18),
                                      label: const Text('Re-open Run'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(12),

                    // Process Timeline
                    _buildProcessTimeline(status),
                    const Gap(12),

                    // Transit Route & Destination Card
                    Builder(
                      builder: (context) {
                        final destDoorstep =
                            delivery?['dest_pickup_station_address']
                                ?.toString();
                        final hasRoute = originStation != null ||
                            destStation != null ||
                            (destDoorstep != null && destDoorstep.isNotEmpty);

                        if (!hasRoute) return const SizedBox.shrink();

                        return Column(
                          children: [
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.2)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.route,
                                            size: 20, color: Color(0xFF1B3A0A)),
                                        const Gap(8),
                                        Text(
                                          'Transit Route & Destination',
                                          style: context.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const Gap(14),

                                    // Origin
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Color(0x22E48629),
                                          child: Icon(Icons.storefront_rounded,
                                              size: 14,
                                              color: Color(0xFFE48629)),
                                        ),
                                        const Gap(10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Dispatch Origin',
                                                  style:
                                                      smallTextStyle?.copyWith(
                                                          color: manatee)),
                                              Text(
                                                originStation != null
                                                    ? '${originStation!['name']} (${originStation!['city'] ?? ''})'
                                                    : 'Merchant Store / Warehouse',
                                                style: context.bodyMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                              ),
                                              if (originStation?['address'] !=
                                                  null)
                                                Text(
                                                  originStation!['address']
                                                      .toString(),
                                                  style:
                                                      smallTextStyle?.copyWith(
                                                          color: manatee),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const Padding(
                                      padding: EdgeInsets.only(left: 11),
                                      child: SizedBox(
                                        height: 16,
                                        child: VerticalDivider(
                                            thickness: 2, color: Colors.grey),
                                      ),
                                    ),

                                    // Destination (Station or Customer Doorstep)
                                    if (destStation != null) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Color(0x221B3A0A),
                                            child: Icon(Icons.location_on,
                                                size: 14,
                                                color: Color(0xFF1B3A0A)),
                                          ),
                                          const Gap(10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'Destination Collection Station',
                                                    style: smallTextStyle
                                                        ?.copyWith(
                                                            color: manatee)),
                                                Text(
                                                  '${destStation!['name']} (${destStation!['city'] ?? ''})',
                                                  style: context.bodyMedium
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                ),
                                                if (destStation!['address'] !=
                                                    null)
                                                  Text(
                                                    destStation!['address']
                                                        .toString(),
                                                    style: smallTextStyle
                                                        ?.copyWith(
                                                            color: manatee),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (destDoorstep != null &&
                                        destDoorstep.isNotEmpty) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Color(0x221B3A0A),
                                            child: Icon(Icons.home_rounded,
                                                size: 14,
                                                color: Color(0xFF1B3A0A)),
                                          ),
                                          const Gap(10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'Customer Delivery Address (Doorstep)',
                                                    style: smallTextStyle
                                                        ?.copyWith(
                                                            color: manatee)),
                                                Text(
                                                  destDoorstep,
                                                  style: context.bodyMedium
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const Gap(12),
                          ],
                        );
                      },
                    ),

                    // Fulfillment Partner / In-House Model Card
                    if (logisticsOrg != null) ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0x181B3A0A),
                                child: Icon(Icons.business,
                                    color: Color(0xFF1B3A0A)),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Logistics Partner',
                                        style: smallTextStyle?.copyWith(
                                            color: manatee)),
                                    Text(
                                      logisticsOrg!['name']?.toString() ??
                                          'Partner',
                                      style: context.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (logisticsOrg!['contact_person'] != null)
                                      Text(
                                        'Contact: ${logisticsOrg!['contact_person']}',
                                        style: smallTextStyle?.copyWith(
                                            color: manatee),
                                      ),
                                  ],
                                ),
                              ),
                              if (logisticsOrg!['phone'] != null)
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.phone,
                                      color: Color(0xFF1B3A0A), size: 18),
                                  onPressed: () => _callNumber(
                                      logisticsOrg!['phone'].toString()),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Gap(12),
                    ] else ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: const Color(0xFF1B3A0A)
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0x181B3A0A),
                                child: Icon(Icons.storefront_rounded,
                                    color: Color(0xFF1B3A0A)),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Fulfillment Model',
                                        style: smallTextStyle?.copyWith(
                                            color: manatee)),
                                    Text(
                                      'In-House Merchant Delivery',
                                      style: context.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1B3A0A)),
                                    ),
                                    Text(
                                      'Direct doorstep delivery handled by store rider',
                                      style: smallTextStyle?.copyWith(
                                          color: manatee, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B3A0A)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'In-House',
                                  style: TextStyle(
                                    color: Color(0xFF1B3A0A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Gap(12),
                    ],

                    // Driver Details Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0x22E48629),
                                  child: Icon(CupertinoIcons.person_fill,
                                      color: Color(0xFFE48629)),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Assigned Driver / Rider',
                                          style: smallTextStyle?.copyWith(
                                              color: manatee)),
                                      Text(driverName,
                                          style: context.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                if (driverPhone.isNotEmpty &&
                                    driverPhone != 'N/A') ...[
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.sms,
                                        color: Color(0xFFE48629), size: 18),
                                    tooltip: 'SMS Driver',
                                    onPressed: () => _smsNumber(driverPhone),
                                  ),
                                  const Gap(6),
                                  IconButton.filledTonal(
                                    icon: const Icon(CupertinoIcons.phone_fill,
                                        color: Colors.green, size: 18),
                                    tooltip: 'Call Driver',
                                    onPressed: () => _callNumber(driverPhone),
                                  ),
                                ],
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Vehicle & Type',
                                          style: smallTextStyle?.copyWith(
                                              color: manatee)),
                                      const Gap(2),
                                      Text('$vehicleType ($vehicleInfo)',
                                          style: context.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Driver Contact',
                                          style: smallTextStyle?.copyWith(
                                              color: manatee)),
                                      const Gap(2),
                                      Text(driverPhone,
                                          style: context.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Delivery Mode',
                                          style: smallTextStyle?.copyWith(
                                              color: manatee)),
                                      const Gap(4),
                                      Chip(
                                        label: Text(deliveryMode,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Route Category',
                                          style: smallTextStyle?.copyWith(
                                              color: manatee)),
                                      const Gap(4),
                                      Chip(
                                        label: Text(routeCategory,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Region',
                                        style: smallTextStyle?.copyWith(
                                            color: manatee)),
                                    const Gap(2),
                                    Text(regionName,
                                        style: context.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Dispatched At',
                                        style: smallTextStyle?.copyWith(
                                            color: manatee)),
                                    const Gap(2),
                                    Text(dateString,
                                        style: context.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(16),

                    // Associated orders
                    Builder(
                      builder: (context) {
                        final rawIds = _parseOrderIds(delivery?['order_ids']);
                        final totalCount =
                            rawIds.isNotEmpty ? rawIds.length : orders.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Associated Orders ($totalCount)',
                                  style: context.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (isLoadingOrders)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator.adaptive(
                                        strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const Gap(8),
                            if (isLoadingOrders && orders.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator.adaptive(),
                                ),
                              )
                            else if (totalCount == 0)
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color:
                                          Colors.grey.withValues(alpha: 0.2)),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(
                                    child: Text(
                                        'No orders associated with this delivery.'),
                                  ),
                                ),
                              )
                            else ...[
                              // Render successfully fetched full orders
                              ...orders.map((order) {
                                final total = order.total != null
                                    ? '${(order.total! / 100).toStringAsFixed(2)} ${order.currencyCode.toUpperCase()}'
                                    : 'N/A';
                                final customer = order.customerName;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color:
                                            Colors.grey.withValues(alpha: 0.2)),
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      context.pushRoute(
                                          OrderDetailsRoute(orderId: order.id));
                                    },
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0x15000000),
                                      child: Icon(Icons.local_shipping,
                                          color: Color(0xFFE48629)),
                                    ),
                                    title: Text('Order #${order.displayId}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        'Customer: $customer\nPayment: ${order.paymentStatus?.name.toUpperCase()}'),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(total,
                                            style: context.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                        const Gap(4),
                                        const Icon(Icons.arrow_forward_ios,
                                            size: 12, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                              // Render resilient fallback cards for order IDs not in full orders list
                              ...rawIds
                                  .where((id) => !orders.any((o) => o.id == id))
                                  .map((id) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color:
                                            Colors.grey.withValues(alpha: 0.2)),
                                  ),
                                  child: ListTile(
                                    onTap: () {
                                      context.pushRoute(
                                          OrderDetailsRoute(orderId: id));
                                    },
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0x15000000),
                                      child: Icon(Icons.local_shipping_outlined,
                                          color: Color(0xFFE48629)),
                                    ),
                                    title: Text('Order: $id',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    subtitle: const Text(
                                        'Linked Run Package • Tap to view order details',
                                        style: TextStyle(fontSize: 12)),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: Colors.grey),
                                  ),
                                );
                              }),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
