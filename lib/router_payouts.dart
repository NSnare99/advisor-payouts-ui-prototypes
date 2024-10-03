import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/Client.dart' as client_model;
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/models/model_services.dart';
import 'package:base/views/root_layout.dart';
import 'package:base/routing/router.dart' as router;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:payouts/payouts_home_screen.dart';
import 'package:payouts/view/account_maintenance/fee_change.dart';
import 'package:payouts/view/files/files.dart';

List<String> payoutsModelNames = [
  Account.schema.name,
  client_model.Client.schema.name,
];

const CustomNavigationDestination payoutsHome = CustomNavigationDestination(
  label: 'Dashboard',
  icon: Icon(Icons.attach_money),
  route: '/payouts',
);

List<CustomNavigationDestination> payoutsDestinations = [
  home,
  payoutsHome,
  ...ModelProvider.instance.modelSchemas
      .where(
        (e) =>
            e.fields != null &&
            payoutsModelNames
                .map((element) => element.toLowerCase())
                .contains(e.name.toLowerCase()),
      )
      .where(
        (e) => !rootOnlyDestinations.any((el) => e.name.toLowerCase().startsWith(el.toLowerCase())),
      )
      .map(
        (e) => CustomNavigationDestination(
          label: e.pluralName?.split(RegExp('(?=[A-Z])')).join(" ") ??
              e.name.split(RegExp('(?=[A-Z])')).join(" "),
          icon: const Icon(Icons.list),
          route: '/payouts/${e.name.toLowerCase()}',
        ),
      ),
  router.blank,
  const CustomNavigationDestination(
    label: 'Statements',
    icon: Icon(Icons.picture_as_pdf),
    route: '/payouts/reports',
  ),
];

List<GoRoute> payoutsRoutes(LocalKey? pageKey, LocalKey? scaffoldKey) {
  List<GoRoute> modelRoutes = modelGoRoutes(
    pageKey: pageKey,
    scaffoldKey: scaffoldKey,
    destinations: payoutsDestinations,
    filterList: payoutsModelNames,
    startingIndex: 2,
  );
  return [
    GoRoute(
      path: '/payouts',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: pageKey,
        child: PayoutsHomeScreen(key: UniqueKey(), scaffoldKey: scaffoldKey),
      ),
      routes: [
        ...modelRoutes,
        GoRoute(
          path: 'reports',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: RootLayout(
              key: scaffoldKey,
              destinations: payoutsDestinations,
              currentIndex: modelRoutes.length + 3,
              child: const Center(
                child: Files(),
              ),
            ),
          ),
        ),
      ],
    ),
  ];
}

List<String> accountColumnOrder = [
  Account.ID.fieldName,
  Account.EXTERNALACCOUNT.fieldName,
  Account.ACCOUNTTYPE.fieldName,
  Account.DISPLAYNAME1.fieldName,
  Account.HOMEEMAIL.fieldName,
  Account.WORKEMAIL.fieldName,
  Account.BIRTHDATE.fieldName,
  Account.ADDRESS1.fieldName,
  Account.ADDRESS2.fieldName,
  Account.CITY.fieldName,
  Account.STATE.fieldName,
  Account.ZIP.fieldName,
  Account.WORKPHONE.fieldName,
  Account.HOMEPHONE.fieldName,
  Account.DISPLAYNAME2.fieldName,
  Account.BIRTHDATE2.fieldName,
  Account.REPID.fieldName,
  Account.REPNAME.fieldName,
  Account.ACCOUNTFEEPERCENTAGE.fieldName,
  Account.ACCOUNTFEENAME.fieldName,
  Account.CLIENTSTATUS.fieldName,
];

List<String> clientColumnOrder = [
  client_model.Client.FIRSTNAME.fieldName,
  client_model.Client.LASTNAME.fieldName,
  client_model.Client.BIRTHDATE.fieldName,
  client_model.Client.ADDRESS.fieldName,
  client_model.Client.CITY.fieldName,
  client_model.Client.STATE.fieldName,
  client_model.Client.ZIPCODE.fieldName,
  client_model.Client.ID.fieldName,
];

List<GoRoute> modelGoRoutes({
  required LocalKey? pageKey,
  required LocalKey? scaffoldKey,
  required List<CustomNavigationDestination> destinations,
  required List<String> filterList,
  required int startingIndex,
}) {
  return [
    ...ModelProvider.instance.modelSchemas
        .where(
          (e) =>
              e.fields != null &&
              getJoinTableData(
                    model: ModelProvider.instance.getModelTypeByModelName(e.name),
                  ) ==
                  null,
        )
        .where(
          (e) =>
              filterList.isEmpty ||
              filterList.map((el) => el.toLowerCase()).contains(e.name.toLowerCase()),
        )
        .mapIndexed(
      (index, e) {
        ModelType<Model> model = ModelProvider.instance.getModelTypeByModelName(e.name);

        Widget tabbed({
          required BuildContext context,
          required GoRouterState state,
          String? itemId,
          int? initialIndex,
        }) =>
            RootLayout(
              key: scaffoldKey,
              destinations: destinations,
              currentIndex: startingIndex + index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: FeeChange(
                  model: model,
                ),
              ),
            );
        return GoRoute(
          path: e.name.toLowerCase(),
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: tabbed(context: context, state: state),
          ),
          routes: [
            GoRoute(
              path: ':iid',
              pageBuilder: (context, state) => MaterialPage(
                key: state.pageKey,
                child: tabbed(
                  context: context,
                  state: state,
                  itemId: state.pathParameters['iid'],
                  initialIndex: 1,
                ),
              ),
            ),
          ],
        );
      },
    ),
  ];
}
