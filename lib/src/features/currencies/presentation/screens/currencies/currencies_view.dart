import 'package:medusa_admin/src/features/store_details/presentation/bloc/store/store_state_extension.dart';
import 'package:medusa_admin/src/core/extensions/snack_bar_extension.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:medusa_admin/src/core/constants/colors.dart';
import 'package:medusa_admin/src/core/extensions/string_extension.dart';
import 'package:medusa_admin/src/core/utils/easy_loading.dart';
import 'package:medusa_admin/src/core/utils/hide_keyboard.dart';
import 'package:medusa_admin/src/core/utils/pagination_error_page.dart';
import 'package:medusa_admin/src/features/store_details/presentation/bloc/store/store_bloc.dart';
import 'package:medusa_admin/src/features/currencies/presentation/cubits/currencies/currencies_cubit.dart';
import 'package:medusa_admin_dart_client/medusa_admin_dart_client_v2.dart';
import 'package:medusa_admin/src/core/extensions/context_extension.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:medusa_admin/src/core/extensions/text_style_extension.dart';

@RoutePage()
class CurrenciesView extends StatefulWidget {
  const CurrenciesView({super.key});

  @override
  State<CurrenciesView> createState() => _CurrenciesViewState();
}

class _CurrenciesViewState extends State<CurrenciesView> {
  late List<Currency> currencies;
  late Currency? defaultStoreCurrency;
  late StoreBloc storeBloc;
  Store? store;
  void _populateCurrencies(Store? s) {
    store = s;
    final supportedCurrencies = s?.supportedCurrencies;
    currencies = supportedCurrencies?.map((sc) {
      return Currency(
        code: sc.currencyCode,
        name: sc.currency?.name ?? sc.currencyCode?.toUpperCase() ?? '',
        symbol: sc.currency?.symbol ?? sc.currencyCode ?? '',
        symbolNative: sc.currency?.symbolNative ?? sc.currency?.symbol ?? '',
      );
    }).toList() ?? [];
    
    final defaultCode = s?.supportedCurrencies
        ?.where((sc) => sc.isDefault == true)
        .firstOrNull
        ?.currencyCode;
    final matchingCurrencies = currencies.where(
      (c) => c.code?.toLowerCase() == defaultCode?.toLowerCase(),
    );
    defaultStoreCurrency = matchingCurrencies.isNotEmpty
        ? matchingCurrencies.first
        : currencies.firstOrNull;
  }

  @override
  void initState() {
    storeBloc = StoreBloc.instance;
    final storeState = storeBloc.state;
    store = storeState.currentStore;
    if (store == null) {
      storeBloc.add(const StoreEvent.loadStores(null));
    }
    _populateCurrencies(store);
    super.initState();
  }

  @override
  void dispose() {
    storeBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const manatee = ColorManager.manatee;
    final mediumTextStyle = context.bodyMedium;
    final largeTextStyle = context.bodyLarge;
    const space = Gap(12);
    return BlocConsumer<StoreBloc, StoreState>(
      bloc: storeBloc,
      listener: (context, state) {
        state.maybeWhen(
          loading: () => loading(),
          store: (_) {
            dismissLoading();
            context.showSnackBar('Currencies updated successfully');
            context.maybePop();
          },
          error: (e) {
            dismissLoading();
            context.showSnackBar(e.toSnackBarString());
          },
          orElse: () => dismissLoading(),
        );
      },
      builder: (context, state) {
        final currentStore = state.currentStore ?? store;
        if (currencies.isEmpty && currentStore != null) {
          _populateCurrencies(currentStore);
        }
        return HideKeyboard(
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  final popped = await context.maybePop();
                  if (!popped && context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
              systemOverlayStyle: context.defaultSystemUiOverlayStyle,
              title: const Text('Currencies'),
              actions: [
                TextButton(
                    onPressed: () async {
                      if (store == null) return;
                      final storeCurrencies = currencies.map((c) {
                        final isDefault = c.code?.toLowerCase() == defaultStoreCurrency?.code?.toLowerCase();
                        return StoreCurrency(
                          id: 'curr_${store!.id}_${c.code}',
                          currencyCode: c.code ?? '',
                          storeId: store!.id,
                          isDefault: isDefault,
                          currency: c,
                        );
                      }).toList();
                      storeBloc.add(
                        StoreEvent.updateStore(
                          store!.id,
                          UpdateStoreReq(
                            supportedCurrencies: storeCurrencies,
                          ),
                        ),
                      );
                    },
                    child: const Text('Save')),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(12.0),
                children: [
                  Text('Manage the markets that you will operate within.',
                      style: mediumTextStyle!.copyWith(color: manatee)),
                  space,
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12.0)),
                      color: context.theme.cardColor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Default store currency', style: largeTextStyle),
                        Text('This is the currency your prices are shown in.',
                            style: mediumTextStyle.copyWith(color: manatee)),
                        space,
                        if (currencies.length == 1)
                          Text(currencies.first.name ?? ''),
                        if (currencies.length > 1)
                          DropdownButtonFormField<String>(
                            initialValue: defaultStoreCurrency?.code,
                            style: context.bodyMedium,
                            items: currencies
                                .map((currency) => DropdownMenuItem(
                                      value: currency.code,
                                      child: Text(currency.name ?? ''),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                defaultStoreCurrency = currencies
                                    .where((element) => element.code == value)
                                    .first;
                              }
                            },
                            decoration: InputDecoration(
                              fillColor: context.theme.scaffoldBackgroundColor,
                              filled: true,
                              border: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(4.0)),
                                  borderSide: BorderSide(color: Colors.grey)),
                            ),
                          ),
                        const SizedBox(height: 6.0),
                      ],
                    ),
                  ),
                  space,
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12.0)),
                      color: context.theme.expansionTileTheme.backgroundColor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Store currencies',
                                      style: largeTextStyle),
                                  Text(
                                      'All the currencies available in your store.',
                                      style: mediumTextStyle.copyWith(
                                          color: manatee)),
                                ],
                              ),
                            ),
                            TextButton(
                                onPressed: () async {
                                  List<Currency>? result =
                                      await showBarModalBottomSheet(
                                    expand: true,
                                    context: context,
                                    overlayStyle: context
                                        .theme.appBarTheme.systemOverlayStyle,
                                    backgroundColor:
                                        context.theme.scaffoldBackgroundColor,
                                    builder: (context) => AllCurrenciesView(
                                        storeCurrencies: currencies),
                                  );
                                  if (result != null) {
                                    currencies = result;
                                    if (!currencies.any((element) =>
                                        element == defaultStoreCurrency)) {
                                      defaultStoreCurrency = result.first;
                                    }
                                    setState(() {});
                                  }
                                },
                                child: const Text('Edit'))
                          ],
                        ),
                        space,
                        if (currencies.isNotEmpty)
                          ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final currency = currencies[index];
                                return ListTile(
                                  title: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(currency.code.getCurrencySymbol),
                                      const SizedBox(width: 12.0),
                                      Text(currency.name ?? ''),
                                    ],
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) => const Divider(),
                              itemCount: currencies.length),
                        const SizedBox(height: 6.0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AllCurrenciesView extends StatefulWidget {
  const AllCurrenciesView({super.key, required this.storeCurrencies});
  final List<Currency> storeCurrencies;

  @override
  State<AllCurrenciesView> createState() => _AllCurrenciesViewState();
}

class _AllCurrenciesViewState extends State<AllCurrenciesView> {
  late CurrenciesCubit currenciesCubit;
  final PagingController<int, Currency> pagingController =
      PagingController(firstPageKey: 0, invisibleItemsThreshold: 6);
  List<Currency> selectedCurrencies = [];

  void _loadPage(int pageKey) {
    currenciesCubit.loadAll(queryParameters: {
      'offset': pagingController.itemList?.length,
    });
  }

  @override
  void initState() {
    currenciesCubit = CurrenciesCubit.instance;
    pagingController.addPageRequestListener(_loadPage);
    selectedCurrencies.addAll(widget.storeCurrencies);
    super.initState();
  }

  @override
  void dispose() {
    currenciesCubit.close();
    pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CurrenciesCubit, CurrenciesState>(
      bloc: currenciesCubit,
      listener: (context, state) {
        state.maybeWhen(
          currencies: (currencies, count) {
            final isLastPage = currencies.length < CurrenciesCubit.pageSize;
            if (isLastPage) {
              pagingController.appendLastPage(currencies);
            } else {
              final nextPageKey =
                  pagingController.nextPageKey ?? 0 + currencies.length;
              pagingController.appendPage(currencies, nextPageKey);
            }
          },
          error: (failure) {
            pagingController.error = failure;
          },
          orElse: () {},
        );
      },
      child: HideKeyboard(
        child: Material(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Add Store Currencies'),
              actions: [
                if (selectedCurrencies.isNotEmpty)
                  TextButton(
                      onPressed: () => context.maybePop(selectedCurrencies),
                      child: const Text('Save')),
              ],
            ),
            body: SafeArea(
              child: PagedListView.separated(
                padding: const EdgeInsets.all(12.0),
                pagingController: pagingController,
                builderDelegate: PagedChildBuilderDelegate<Currency>(
                  animateTransitions: true,
                  itemBuilder: (context, currency, index) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(currency.name ?? ''),
                    secondary: Text(currency.code.getCurrencySymbol,
                        style: context.bodyMediumW600),
                    onChanged: (value) {
                      if (selectedCurrencies
                          .any((element) => element.code == currency.code)) {
                        selectedCurrencies.removeWhere(
                            (element) => element.code == currency.code);
                      } else {
                        selectedCurrencies.add(currency);
                      }
                      setState(() {});
                    },
                    value: selectedCurrencies
                        .any((element) => element.code == currency.code),
                  ),
                  firstPageProgressIndicatorBuilder: (context) =>
                      const Center(child: CircularProgressIndicator.adaptive()),
                  firstPageErrorIndicatorBuilder: (_) =>
                      PaginationErrorPage(pagingController: pagingController),
                ),
                separatorBuilder: (_, __) => const Divider(height: 0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
