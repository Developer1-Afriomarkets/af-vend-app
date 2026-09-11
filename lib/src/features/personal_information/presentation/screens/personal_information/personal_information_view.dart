import 'package:medusa_admin/src/core/routing/app_router.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:medusa_admin/src/core/extensions/snack_bar_extension.dart';
import 'package:medusa_admin/src/core/utils/medusa_icons_icons.dart';
import 'package:medusa_admin/src/core/utils/custom_text_field.dart';
import 'package:medusa_admin/src/core/utils/easy_loading.dart';
import 'package:medusa_admin/src/features/team/presentation/bloc/user_crud/user_crud_bloc.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';
import 'components/personal_info_tile.dart';

@RoutePage()
class PersonalInformationView extends StatefulWidget {
  const PersonalInformationView({super.key});

  @override
  State<PersonalInformationView> createState() =>
      _PersonalInformationViewState();
}

class _PersonalInformationViewState extends State<PersonalInformationView> {
  late UserCrudBloc userCrudBloc;
  late UserCrudBloc userBloc;
  final formKey = GlobalKey<FormState>();
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();

  @override
  void initState() {
    userCrudBloc = UserCrudBloc.instance;
    userBloc = UserCrudBloc.instance;
    userBloc.add(const UserCrudEvent.loadCurrentUser());
    super.initState();
  }

  @override
  void dispose() {
    userCrudBloc.close();
    userBloc.close();
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserCrudBloc, UserCrudState>(
      bloc: userCrudBloc,
      listener: (context, state) {
        state.maybeWhen(
          loading: () => loading(),
          user: (_) {
            dismissLoading();
            context.showSnackBar('User updated');
            userBloc.add(const UserCrudEvent.loadCurrentUser());
          },
          error: (e) {
            dismissLoading();
            context.showSnackBar(e.toSnackBarString());
          },
          orElse: () => dismissLoading(),
        );
      },
      child: BlocBuilder<UserCrudBloc, UserCrudState>(
        bloc: userBloc,
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.maybePop(),
              ),
              title: const Text('Personal Information'),
            ),
            floatingActionButton: state.whenOrNull(
              user: (user) => FloatingActionButton.extended(
                onPressed: () async => await updatePersonalInformation(user),
                label: const Text('Edit'),
                icon: const Icon(MedusaIcons.pencil_square_solid),
              ),
            ),
            body: SafeArea(
              child: state.maybeWhen(
                loading: () => const Skeletonizer(
                    enabled: true,
                    child: PersonalInfoTile(User(
                      email: 'admin@medusa-test.com',
                      firstName: 'Medusa',
                      lastName: 'Js',
                      id: '',
                    ))),
                user: (user) => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  children: [
                    PersonalInfoTile(
                      user,
                      onTap: () async => await updatePersonalInformation(user),
                    ),
                    const SizedBox(height: 16.0),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Icon(Icons.auto_awesome_outlined, color: Colors.deepPurple.shade600),
                        ),
                        title: const Text('Store & Profile Wizard', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Update your complete store address, commercial market, and personal details.'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          await context.pushRoute(const AccountUpdateWizardRoute());
                          userBloc.add(const UserCrudEvent.loadCurrentUser());
                        },
                      ),
                    ),
                  ],
                ),
                error: (e) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.amber.shade700),
                        const SizedBox(height: 16.0),
                        Text(
                          'Unable to load personal information',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          e.toSnackBarString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 20.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => userBloc.add(const UserCrudEvent.loadCurrentUser()),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                            const SizedBox(width: 12.0),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await context.pushRoute(const AccountUpdateWizardRoute());
                                userBloc.add(const UserCrudEvent.loadCurrentUser());
                              },
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('Open Wizard'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> updatePersonalInformation(User user) async {
    firstNameCtrl.text = user.firstName ?? '';
    lastNameCtrl.text = user.lastName ?? '';
    widgetBuilder(BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
            top: 8.0,
            left: 12.0,
            right: 12.0,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => context.pop()),
                TextButton(
                  child: const Text('Update'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    if (firstNameCtrl.text == user.firstName &&
                        lastNameCtrl.text == user.lastName) {
                      context.pop();
                    } else {
                      context.unfocus();
                      userCrudBloc.add(UserCrudEvent.update(
                          user.id,
                          UserUpdateReq(
                              firstName: firstNameCtrl.text,
                              lastName: lastNameCtrl.text)));
                      context.pop();
                    }
                  },
                ),
              ],
            ),
            Form(
                key: formKey,
                child: Column(
                  children: [
                    LabeledTextField(
                      label: 'First Name',
                      hintText: 'First Name ...',
                      controller: firstNameCtrl,
                      autoFocus: true,
                      validator: (val) {
                        if (val != null && val.isEmpty) {
                          return 'Field is required';
                        }
                        return null;
                      },
                    ),
                    LabeledTextField(
                      label: 'Last Name',
                      hintText: 'Last Name ...',
                      controller: lastNameCtrl,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        if (firstNameCtrl.text == user.firstName &&
                            lastNameCtrl.text == user.lastName) {
                          context.pop();
                        } else {
                          context.unfocus();
                          userCrudBloc.add(UserCrudEvent.update(
                              user.id,
                              UserUpdateReq(
                                  firstName: firstNameCtrl.text,
                                  lastName: lastNameCtrl.text)));
                          context.pop();
                        }
                      },
                      validator: (val) {
                        if (val != null && val.isEmpty) {
                          return 'Field is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ))
          ],
        ),
      );
    }

    if ((defaultTargetPlatform == TargetPlatform.iOS)) {
      await showCupertinoModalBottomSheet(
          context: context, builder: widgetBuilder);
    } else {
      await showModalBottomSheet(
          context: context, builder: widgetBuilder, isScrollControlled: true);
    }
  }
}
