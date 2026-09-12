import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:medusa_admin/src/core/services/app_scope_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../invites/components/invite_user.dart';
import 'package:flutter/foundation.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:medusa_admin/src/core/utils/medusa_sliver_app_bar.dart';
import 'package:medusa_admin/src/features/team/presentation/bloc/user_crud/user_crud_bloc.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'components/index.dart';

@RoutePage()
class TeamView extends StatefulWidget {
  const TeamView({super.key});

  @override
  State<TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends State<TeamView> {
  late UserCrudBloc userCrudBloc;
  final refreshController = RefreshController();
  final pagingController =
      PagingController<int, User>(firstPageKey: 0, invisibleItemsThreshold: 3);
  String? _adminUserId;

  Future<void> _loadAdminInfo() async {
    try {
      if (AppScopeService.isLogistics && AppScopeService.currentLogisticsOrgId != null) {
        final org = await Supabase.instance.client
            .from('logistics_orgs')
            .select('contact_info')
            .eq('id', AppScopeService.currentLogisticsOrgId!)
            .maybeSingle();
        if (mounted && org != null && org['contact_info'] is Map) {
          setState(() {
            _adminUserId = org['contact_info']['admin_user_id']?.toString();
          });
        }
      } else if (AppScopeService.isVendor && AppScopeService.currentStoreId != null) {
        final store = await Supabase.instance.client
            .from('store')
            .select('metadata')
            .eq('id', AppScopeService.currentStoreId!)
            .maybeSingle();
        if (mounted && store != null && store['metadata'] is Map) {
          setState(() {
            _adminUserId = store['metadata']['vendor_user_id']?.toString();
          });
        }
      }
    } catch (_) {}
  }

  void _loadPage(int page) {
    final Map<String, dynamic> params = {
      'offset': page == 0 ? 0 : pagingController.itemList?.length,
      'scope': AppScopeService.currentScope.name,
    };
    if (AppScopeService.isLogistics || AppScopeService.isRider) {
      if (AppScopeService.currentLogisticsOrgId != null) {
        params['logistics_org_id'] = AppScopeService.currentLogisticsOrgId;
      }
    } else if (AppScopeService.isVendor) {
      if (AppScopeService.currentStoreId != null) {
        params['store_id'] = AppScopeService.currentStoreId;
      }
    }
    userCrudBloc.add(UserCrudEvent.loadAll(queryParameters: params));
  }

  @override
  void initState() {
    userCrudBloc = UserCrudBloc.instance;
    pagingController.addPageRequestListener(_loadPage);
    _loadAdminInfo();
    super.initState();
  }

  @override
  void dispose() {
    userCrudBloc.close();
    refreshController.dispose();
    pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserCrudBloc, UserCrudState>(
      bloc: userCrudBloc,
      listener: (context, state) {
        state.mapOrNull(
          users: (state) async {
            final isLastPage = state.users.length < UserCrudBloc.pageSize;
            if (refreshController.isRefresh) {
              pagingController.removePageRequestListener(_loadPage);
              pagingController.value = const PagingState(
                  nextPageKey: null, error: null, itemList: null);
              await Future.delayed(const Duration(milliseconds: 250));
            }
            if (isLastPage) {
              pagingController.appendLastPage(state.users);
            } else {
              final nextPageKey =
                  pagingController.nextPageKey ?? 0 + state.users.length;
              pagingController.appendPage(state.users, nextPageKey);
            }
            if (refreshController.isRefresh) {
              pagingController.addPageRequestListener(_loadPage);
              refreshController.refreshCompleted();
            }
          },
          error: (state) {
            refreshController.refreshFailed();
            pagingController.error = state.failure;
          },
        );
      },
      child: Scaffold(
        floatingActionButton: (AppScopeService.isLogistics ? AppScopeService.isLogisticsAdmin : AppScopeService.isVendorAdmin)
            ? FloatingActionButton.extended(
                icon: const Icon(LucideIcons.userPlus),
                label: Text(AppScopeService.isLogistics ? 'Invite Fleet Staff' : 'Invite Store Member'),
                onPressed: () async {
                  final result = await showModalBottomSheet<bool?>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => const InviteUser(),
                  );
                  if (result == true) {
                    pagingController.refresh();
                  }
                },
              )
            : null,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            MedusaSliverAppBar(
              title: Text(AppScopeService.isLogistics
                  ? '${AppScopeService.organizationName} Dispatch Team'
                  : (AppScopeService.displayName.isNotEmpty
                      ? '${AppScopeService.displayName} Team'
                      : 'Store Team Members')),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.maybePop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.mail),
                  tooltip: 'Staff Invitations',
                  onPressed: () => context.pushRoute(const InvitesRoute()),
                ),
              ],
            ),
          ],
          body: SmartRefresher(
            controller: refreshController,
            onRefresh: () => _loadPage(0),
            child: PagedListView(
              pagingController: pagingController,
              builderDelegate: PagedChildBuilderDelegate<User>(
                animateTransitions: true,
                itemBuilder: (context, user, index) {
                  final userIsAdmin = _adminUserId != null
                      ? (user.id == _adminUserId)
                      : (AppScopeService.isLogistics
                          ? AppScopeService.isLogisticsAdmin
                          : AppScopeService.isVendorAdmin);
                  return TeamCard(
                    user: user,
                    isAdmin: userIsAdmin,
                    onEditTap: () async {
                      if (defaultTargetPlatform == TargetPlatform.iOS) {
                        await showCupertinoModalBottomSheet(
                            context: context,
                            builder: (_) => UpdateUserCard(
                                user: user,
                                onUpdated: (userUpdateUserReq) {
                                  userCrudBloc.add(UserCrudEvent.update(
                                      user.id, userUpdateUserReq));
                                }));
                      } else {
                        await showModalBottomSheet(
                            context: context,
                            builder: (_) => UpdateUserCard(
                                user: user,
                                onUpdated: (userUpdateUserReq) {
                                  userCrudBloc.add(UserCrudEvent.update(
                                      user.id, userUpdateUserReq));
                                }),
                            isScrollControlled: true);
                      }
                    },
                    onDeleteTap: () async {
                      if (await delete) {
                        userCrudBloc.add(UserCrudEvent.delete(user.id));
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> get delete async => await showOkCancelAlertDialog(
        context: context,
        title: 'Remove user',
        message: 'Are you sure you want to remove this user?',
        okLabel: 'Yes, remove',
        isDestructiveAction: true,
      ).then((value) => value == OkCancelResult.ok);
}
