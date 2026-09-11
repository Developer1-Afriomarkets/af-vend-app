import 'package:auto_route/auto_route.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/services/app_scope_service.dart';

class ScopeBadge extends StatelessWidget {
  const ScopeBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppScope>(
      valueListenable: AppScopeService.activeScopeNotifier,
      builder: (context, scope, _) {
        return ValueListenableBuilder<List<AppScope>>(
          valueListenable: AppScopeService.allowedScopesNotifier,
          builder: (context, allowed, _) {
            final hasMultiple = allowed.length > 1;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => showScopeSwitcherSheet(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8.0 : 10.0,
                    vertical: compact ? 3.0 : 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: scope.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scope.color.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        scope.badgeEmoji,
                        style: TextStyle(fontSize: compact ? 11 : 13),
                      ),
                      const Gap(5),
                      Text(
                        compact ? scope.shortLabel : scope.label,
                        style: GoogleFonts.comfortaa(
                          color: Colors.white,
                          fontSize: compact ? 10.5 : 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(4),
                      Icon(
                        hasMultiple ? Icons.keyboard_arrow_down_rounded : Icons.add_circle_outline_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> showScopeSwitcherSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const ScopeSwitcherSheet(),
  );
}

class ScopeSwitcherSheet extends StatelessWidget {
  const ScopeSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return ValueListenableBuilder<AppScope>(
      valueListenable: AppScopeService.activeScopeNotifier,
      builder: (context, currentScope, _) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181C14) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 25,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Gap(16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE48629).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Color(0xFFE48629),
                        size: 22,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Switch Operational Scope',
                            style: GoogleFonts.comfortaa(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Select your active work profile & access mode',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(18),
                ...AppScopeService.allowedScopes.map((scope) {
                  final isSelected = scope == currentScope;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await AppScopeService.setScope(scope);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Switched to ${scope.label} Mode',
                                  style: GoogleFonts.comfortaa(fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: scope.color,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scope.color.withValues(alpha: isDark ? 0.22 : 0.12)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? scope.color
                                  : isDark
                                      ? Colors.white12
                                      : Colors.grey.shade200,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: scope.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    scope.badgeEmoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                              const Gap(14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            scope.label,
                                            style: GoogleFonts.comfortaa(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? (isDark ? Colors.white : scope.color)
                                                  : (isDark ? Colors.white70 : Colors.black87),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const Gap(8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: scope.color,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'ACTIVE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const Gap(3),
                                    Text(
                                      scope.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(8),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? scope.color : Colors.grey.shade400,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                
                // Cross-Role Account Expansion Section
                Builder(builder: (context) {
                  final unadded = [
                    AppScope.vendor,
                    AppScope.logistics,
                    AppScope.rider,
                  ].where((s) => !AppScopeService.allowedScopes.contains(s)).toList();

                  if (unadded.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Gap(12),
                      const Divider(),
                      const Gap(10),
                      Text(
                        'EXPAND ACCOUNT CAPABILITIES',
                        style: GoogleFonts.comfortaa(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                      const Gap(10),
                      ...unadded.map((scope) {
                        String title = '';
                        String subtitle = '';
                        VoidCallback onTapAction = () {};

                        switch (scope) {
                          case AppScope.vendor:
                            title = 'Register as Vendor Store';
                            subtitle = 'Start selling your catalog & goods on Afrio Marketplace';
                            onTapAction = () {
                              Navigator.pop(context);
                              context.pushRoute(const AccountUpdateWizardRoute());
                            };
                            break;
                          case AppScope.logistics:
                            title = 'Join as Logistics Carrier / Fleet';
                            subtitle = 'Manage collection stations, freight dispatch & intake hubs';
                            onTapAction = () {
                              Navigator.pop(context);
                              context.pushRoute(const LogisticsOnboardingWizardRoute());
                            };
                            break;
                          case AppScope.rider:
                            title = 'Register as Dispatch Rider';
                            subtitle = 'Accept delivery runs and drop packages on demand';
                            onTapAction = () async {
                              Navigator.pop(context);
                              await AppScopeService.addAllowedScope(AppScope.rider, switchToNewScope: true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Activated Rider Cockpit Scope!')),
                                );
                              }
                            };
                            break;
                          case AppScope.admin:
                            break;
                        }

                        if (title.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: onTapAction,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: scope.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(scope.badgeEmoji, style: const TextStyle(fontSize: 18)),
                                    ),
                                  ),
                                  const Gap(12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const Gap(2),
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Gap(8),
                                  Icon(Icons.add_circle_outline, color: scope.accentColor, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
                const Gap(8),
              ],
            ),
          ),
        );
      },
    );
  }
}
