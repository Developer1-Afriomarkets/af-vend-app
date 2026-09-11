import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';

class OrderDetailsErrorPage extends StatelessWidget {
  const OrderDetailsErrorPage(
    this.message, {
    super.key,
    this.onRetryTap,
  });
  final String message;
  final void Function()? onRetryTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const Gap(14.0),
            Text('Error Retrieving Order Details', style: context.bodyLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const Gap(10.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Gap(20.0),
            FilledButton.icon(
              onPressed: onRetryTap,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry Order Retrieval'),
            ),
          ],
        ),
      ),
    );
  }
}
