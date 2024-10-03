import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/models/Client.dart' as client_model;
import 'package:base/providers/auth_state.dart';
import 'package:base/utilities/aws_cognito/src/cognito_user_attribute.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:payouts/router_payouts.dart';
import 'package:payouts/view/dashboards/amCharts5/bar_chart.dart';
import 'package:payouts/view/dashboards/amCharts5/logic_am_charts.dart';
import 'package:payouts/view/dashboards/amCharts5/pie_chart.dart';
import 'package:payouts/view/dashboards/views/dashboard_card_flip.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:rms/view/adaptive_grid.dart';
import 'package:rms/view/explore/explorer_data.dart';
import 'package:rms/view/explore/explorer_graphql.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:web_plugins/web_plugins.dart';

class Dashboard extends StatefulWidget {
  final List<User> users;
  const Dashboard({super.key, required this.users});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool loading = true;
  Map<String, dynamic> dashBoardSummaries = {};
  bool showingGrid = false;
  String label = "";
  int count = 0;
  int _rowsPerPage = 50;
  String chartId = "";
  bool hideDashboard = false;

  ModelType<Model> selectedModel = Account.classType;
  User? selectedUser;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();
  List<CognitoUserAttribute>? attributes;

  @override
  void dispose() {
    WebPlugins().removeEventListener("chartId");
    WebPlugins().removeEventListener("scrollId");
    super.dispose();
  }

  String getGreeting() {
    String name = '';
    for (CognitoUserAttribute attribute in attributes ?? []) {
      if (attribute.name == 'name') {
        name = attribute.value ?? '';
        break;
      }
    }
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning $name';
    } else if (hour < 17) {
      return 'Afternoon $name';
    } else {
      return 'Evening $name';
    }
  }

  @override
  void didChangeDependencies() {
    bool isDark = false;
    if (mounted) {
      isDark = Theme.of(context).brightness == Brightness.dark;
    }
    Map<String, dynamic> themeMessage = {
      'type': 'updateChartTheme',
      'data': isDark,
    };
    WebPlugins().sendMessageToIframe(categoryId, themeMessage);
    WebPlugins().sendMessageToIframe(headOfHouseholdId, themeMessage);
    WebPlugins().sendMessageToIframe(feeRangeId, themeMessage);
    WebPlugins().sendMessageToIframe(feeRangeNameId, themeMessage);
    WebPlugins().sendMessageToIframe(ageBandId, themeMessage);
    WebPlugins().sendMessageToIframe(occupationStatusId, themeMessage);
    WebPlugins().sendMessageToIframe(sourceId, themeMessage);
    WebPlugins().sendMessageToIframe(payHistoryId, themeMessage);
    WebPlugins().sendMessageToIframe(investmentStrategyId, themeMessage);
    super.didChangeDependencies();
  }

  void changeVisibility() {
    setState(() {
      showingGrid = !showingGrid;
    });
  }

  ScrollController scrollController = ScrollController();

  DateTime subtractMonths(DateTime date, int months) {
    int year = date.year;
    int month = date.month - months;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    // Handle the edge case where the day might be invalid in the new month
    int day = date.day;
    while (true) {
      try {
        return DateTime(year, month, day, date.hour, date.minute, date.second, date.millisecond,
            date.microsecond);
      } catch (e) {
        day -= 1;
      }
    }
  }

  @override
  void initState() {
    setState(() {
      startDate = subtractMonths(DateTime.now(), 6);
      endDate = DateTime.parse(
          "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-01");
      if (widget.users.isNotEmpty) {
        selectedUser = widget.users.firstOrNull;
      }
      loading = true;
    });

    // Set this once with the initial app or somewhere where it will not be rebuilt on resize
    // you may need to set this in an initState
    if (kIsWeb && mounted) {
      WebPlugins().onMessageListen("chartId", (data) {
        // Ensure the message contains the expected structure
        if (data is Map &&
            data.containsKey('chartId') &&
            data.containsKey('value') &&
            data.containsKey('label')) {
          setState(() {
            label = data['label'];
            count = int.parse(data['value']?.toString() ?? "");
            chartId = data['chartId'];
          });
          displayChartSelectionGrid(context, data['chartId']);
          // Handle the received data (both value and label) as needed
        }
      });
      WebPlugins().onMessageListen("chartLoadId", (data) {
        if (data is Map && data.containsKey('chartLoadId')) {
          bool isDark = (Theme.of(context).brightness == Brightness.dark);
          Map<String, dynamic> themeMessage = {
            'type': 'updateChartTheme',
            'data': isDark,
          };
          Map<String, dynamic> message = {};
          if (data["chartLoadId"] == categoryId) {
            message = {
              'type': 'updateChartData',
              'newData': (clientItemData['category'] ?? {})
                  .values
                  .toList()
                  .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                  .toList(),
            };
            WebPlugins().sendMessageToIframe(categoryId, message);
            WebPlugins().sendMessageToIframe(categoryId, themeMessage);
          }
          if (data["chartLoadId"] == headOfHouseholdId) {
            message = {
              'type': 'updateChartData',
              'newData': (clientItemData['head of household'] ?? {})
                  .values
                  .toList()
                  .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                  .toList(),
            };
            itemData['head of household'] == {}
                ? null
                : WebPlugins().sendMessageToIframe(headOfHouseholdId, message);
            WebPlugins().sendMessageToIframe(headOfHouseholdId, themeMessage);
          }
          if (data["chartLoadId"] == occupationStatusId) {
            message = {
              'type': 'updateChartData',
              'newData': (clientItemData['occupation status'] ?? {})
                  .values
                  .toList()
                  .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                  .toList(),
            };
            WebPlugins().sendMessageToIframe(occupationStatusId, message);
            WebPlugins().sendMessageToIframe(occupationStatusId, themeMessage);
          }
          if (data["chartLoadId"] == sourceId) {
            message = {
              'type': 'updateChartData',
              'newData': (clientItemData['source of client'] ?? {})
                  .values
                  .toList()
                  .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                  .toList(),
            };
            itemData['source of client'] == {}
                ? null
                : WebPlugins().sendMessageToIframe(sourceId, message);
            WebPlugins().sendMessageToIframe(sourceId, themeMessage);
          }
          if (data["chartLoadId"] == feeRangeId) {
            message = {
              'type': 'updateChartData',
              'newData': ((itemData['dashBoardData']?["accountFeePercentage"] ?? {})
                      as Map<String, dynamic>)
                  .values
                  .toList()
                  .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                  .toList(),
            };
            itemData['dashBoardData']?["accountFeePercentage"] != null &&
                    itemData['dashBoardData']?["accountFeePercentage"] != {}
                ? WebPlugins().sendMessageToIframe(feeRangeId, message)
                : null;
            WebPlugins().sendMessageToIframe(feeRangeId, themeMessage);
          }
          if (data["chartLoadId"] == feeRangeNameId) {
            message = {
              'type': 'updateChartData',
              'newData':
                  ((itemData['dashBoardData']?["accountFeeName"] ?? {}) as Map<String, dynamic>)
                      .values
                      .toList()
                      .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                      .toList(),
            };
            itemData['dashBoardData']?["accountFeeName"] != null &&
                    itemData['dashBoardData']?["accountFeeName"] != {}
                ? WebPlugins().sendMessageToIframe(feeRangeNameId, message)
                : null;
            WebPlugins().sendMessageToIframe(feeRangeNameId, themeMessage);
          }
          if (data["chartLoadId"] == ageBandId) {
            message = {
              'type': 'updateChartData',
              'newData': ((itemData['dashBoardData']?["ageRange"] ?? {}) as Map<String, dynamic>)
                  .values
                  .toList()
                  .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                  .toList(),
            };
            itemData['dashBoardData']?["ageRange"] != null &&
                    itemData['dashBoardData']?["ageRange"] != {}
                ? WebPlugins().sendMessageToIframe(ageBandId, message)
                : null;
            WebPlugins().sendMessageToIframe(ageBandId, themeMessage);
          }
          if (data["chartLoadId"] == payHistoryId) {
            message = {
              'type': 'updateChartData',
              'newData': itemData['payHistory']?.entries.map((e) {
                    return {"date": double.parse(e.key), "value": (e.value as double).toInt()};
                  }).toList() ??
                  [],
            };
            WebPlugins().sendMessageToIframe(payHistoryId, message);
            WebPlugins().sendMessageToIframe(payHistoryId, themeMessage);
          }
          if (data["chartLoadId"] == investmentStrategyId) {
            message = {
              'type': 'updateChartData',
              'newData': (itemData['dashBoardData']?['investmentObjective'] ?? {})
                  .values
                  .toList()
                  .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                  .toList(),
            };
            WebPlugins().sendMessageToIframe(investmentStrategyId, message);
            WebPlugins().sendMessageToIframe(investmentStrategyId, themeMessage);
          }
        }
      });
      WebPlugins().onMessageListen("scrollId", (data) {
        // Ensure the message contains the expected structure
        if (data is Map && scrollController.hasClients) {
          if (data['scrollId']?.toString().toLowerCase() == 'down') {
            scrollController.jumpTo(
              scrollController.position.pixels + 50 >= scrollController.position.maxScrollExtent
                  ? scrollController.position.maxScrollExtent
                  : scrollController.position.pixels + 50,
            );
          }
          if (data['scrollId']?.toString().toLowerCase() == 'up') {
            scrollController.jumpTo(
              scrollController.position.pixels - 50 <= scrollController.position.minScrollExtent
                  ? scrollController.position.minScrollExtent
                  : scrollController.position.pixels - 50,
            );
          }
        }
      });
    }
    loadData();
    super.initState();
  }

  Future<void> loadData() async {
    attributes = await AuthState().cognitoUser?.getUserAttributes();
    SearchResult itemsListAccounts = await searchGraphql(
      model: Account.classType,
      isMounted: () => context.mounted,
      filter:
          'filter: {${Account.CLIENTSTATUS.fieldName}: {eq: "${AccountClientStatusEnum.Active.name}"}, _deleted: {ne: true}}', //, ${Account.CLIENTTABLEID.fieldName} : {eq: "${selectedUser?.id}"}
      nextToken: null,
    );
    itemsListAccounts = itemsListAccounts.copyWith(items: [
      ...?itemsListAccounts.items
          ?.where((i) => selectedUser?.advisorIds?.contains(i[Account.REPID.fieldName]) == true),
    ]);
    int limitMultiplier = ((900 * 1024) / jsonEncode(itemsListAccounts).length).floor();
    while (itemsListAccounts.nextToken != null && itemsListAccounts.nextToken != "") {
      List<Map<String, dynamic>>? allItems = itemsListAccounts.items
          ?.where((i) => selectedUser?.advisorIds?.contains(i[Account.REPID.fieldName]) == true)
          .toList();
      itemsListAccounts = await searchGraphql(
        limit: limitMultiplier > 1
            ? (100 * limitMultiplier) >= 1000
                ? 1000
                : (100 * limitMultiplier)
            : null,
        model: Account.classType,
        isMounted: () => context.mounted,
        nextToken: itemsListAccounts.nextToken != null
            ? Uri.encodeComponent(itemsListAccounts.nextToken!)
            : null,
        filter:
            'filter: {${Account.CLIENTSTATUS.fieldName}: {eq: "${AccountClientStatusEnum.Active.name}"}, _deleted: {ne: true}}', //, ${Account.CLIENTTABLEID.fieldName} : {eq: "${selectedUser?.id}"}
      );
      itemsListAccounts = itemsListAccounts.copyWith(items: [
        ...?itemsListAccounts.items
            ?.where((i) => selectedUser?.advisorIds?.contains(i[Account.REPID.fieldName]) == true),
        ...?allItems
      ]);
    }
    // get tableFields
    Map<String, List<String>> fieldNames = {};
    List<TableField> tableFieldsList = [];
    List<TableFieldOption> tableFieldOptionsList = [];
    SearchResult tableFieldResult = await searchGraphql(
      model: TableField.classType,
      isMounted: () => true,
      limit: 1000,
      filter:
          'filter: {userId: {eq: "default"}, tableSettingCustomFieldsId: {eq: "${client_model.Client.schema.name}"},_deleted: {ne: true} }',
      nextToken: null,
    );
    tableFieldsList.addAll(tableFieldResult.items?.map(TableField.fromJson) ?? []);
    while (tableFieldResult.nextToken != null) {
      tableFieldResult = await searchGraphql(
        model: TableField.classType,
        isMounted: () => true,
        limit: 1000,
        filter:
            'filter: {userId: {eq: "default"}, tableSettingCustomFieldsId: {eq: "${client_model.Client.schema.name}"},_deleted: {ne: true} }',
        nextToken: null,
      );
      tableFieldsList.addAll(tableFieldResult.items?.map(TableField.fromJson) ?? []);
    }
    tableFieldResult = await searchGraphql(
      model: TableField.classType,
      isMounted: () => true,
      limit: 1000,
      filter:
          'filter: {userId: {eq: "${selectedUser?.id}"}, tableSettingCustomFieldsId: {eq: "${client_model.Client.schema.name}"},_deleted: {ne: true} }',
      nextToken: null,
    );
    tableFieldsList.addAll(tableFieldResult.items?.map(TableField.fromJson) ?? []);
    while (tableFieldResult.nextToken != null) {
      tableFieldResult = await searchGraphql(
        model: TableField.classType,
        isMounted: () => true,
        limit: 1000,
        filter:
            'filter: {userId: {eq: "${selectedUser?.id}"}, tableSettingCustomFieldsId: {eq: "${client_model.Client.schema.name}"},_deleted: {ne: true} }',
        nextToken: null,
      );
      tableFieldsList.addAll(tableFieldResult.items?.map(TableField.fromJson) ?? []);
    }
    tableFieldsList.sort((a, b) => a.fieldName?.compareTo(b.fieldName ?? "") ?? 0);
    for (TableField tableField in tableFieldsList) {
      SearchResult tableFieldOptions = await searchGraphql(
        model: TableFieldOption.classType,
        isMounted: () => true,
        filter:
            'filter: {and: [{tableFieldOptionsId: {eq:"${tableField.id}"}},{or: [{repId: {eq : "default"}} ,{repId: {eq : "${selectedUser?.id}"}}]}, {_deleted: {ne: true} }]}',
        limit: 1000,
        nextToken: null,
      );
      tableFieldOptionsList.addAll(
        tableFieldOptions.items?.map(TableFieldOption.fromJson).toList() ?? [],
      );
      while (tableFieldOptions.nextToken != null) {
        tableFieldOptions = await searchGraphql(
          nextToken: Uri.encodeComponent(tableFieldOptions.nextToken ?? ""),
          model: TableFieldOption.classType,
          isMounted: () => true,
          filter:
              'filter: {and: [{tableFieldOptionsId: {eq:"${tableField.id}"}},{or: [{repId: {eq : "default"}} ,{repId: {eq : "${selectedUser?.id}"}}]}, {_deleted: {ne: true} }]}',
          limit: 1000,
        );
        tableFieldOptionsList.addAll(
          tableFieldOptions.items?.map(TableFieldOption.fromJson).toList() ?? [],
        );
      }
      tableFieldOptionsList.sort(
        (a, b) {
          if (a.labelText == null || b.labelText == null) {
            return 0;
          }
          return a.labelText?.toString().compareTo(
                    b.labelText?.toString() ?? "",
                  ) ??
              0;
        },
      );
      fieldNames.addAll({
        (tableField.fieldName ?? ""):
            tableFieldOptionsList.map((tfo) => tfo.labelText ?? "").toList()
      });
    }

    itemData = await processCustomFieldEnum(
      tableFields: tableFieldsList,
      tableFieldOptions: tableFieldOptionsList,
      items: itemsListAccounts.items ?? [],
      selectedUser: selectedUser,
    );

    SearchResult clientItemsList = await searchGraphql(
      model: client_model.Client.classType,
      isMounted: () => context.mounted,
      nextToken: null,
      filter:
          'filter: {${Account.CLIENTSTATUS.fieldName}: {eq: "${AccountClientStatusEnum.Active.name}"}, _deleted: {ne: true}}',
    );
    limitMultiplier = ((900 * 1024) / jsonEncode(clientItemsList).length).floor();
    while (clientItemsList.nextToken != null && clientItemsList.nextToken != "") {
      List<Map<String, dynamic>>? allItems = clientItemsList.items;
      clientItemsList = await searchGraphql(
        limit: limitMultiplier > 1
            ? (100 * limitMultiplier) >= 1000
                ? 1000
                : (100 * limitMultiplier)
            : null,
        model: client_model.Client.classType,
        isMounted: () => context.mounted,
        nextToken: clientItemsList.nextToken != null
            ? Uri.encodeComponent(clientItemsList.nextToken!)
            : null,
        filter:
            'filter: {${Account.CLIENTSTATUS.fieldName}: {eq: "${AccountClientStatusEnum.Active.name}"}, _deleted: {ne: true}}',
      );
      clientItemsList = clientItemsList.copyWith(items: [...?clientItemsList.items, ...?allItems]);
    }

    clientItemData = await processCustomFieldEnum(
      tableFields: tableFieldsList,
      tableFieldOptions: tableFieldOptionsList,
      items: clientItemsList.items ?? [],
      selectedUser: selectedUser,
    );

    await updatePayHistory();

    itemData["dashBoardData"] = await processDashboard(items: itemsListAccounts.items ?? []);
    clientItemData["dashBoardData"] = await processDashboard(items: clientItemsList.items ?? []);

    WebPlugins().iframeElement(
      viewType: payHistoryId,
      generatedHTML: generateAM5BarChartHtml(
          name: payHistoryId,
          data: itemData['payHistory']?.entries.map((e) {
                return {"date": e.key, "value": (e.value as double).toInt()};
              }).toList() ??
              [],
          targetOrigin: '*'),
    );

    WebPlugins().iframeElement(
      viewType: categoryId,
      generatedHTML: generateAM5PieChartHtml(
          allowLegend: false,
          name: categoryId,
          semiCircle: true,
          labels: (clientItemData['category'] ?? {})
              .keys
              .map((e) => e.toFirstUpper().splitCamelCase())
              .toList(),
          backgroundColor: [],
          data: (clientItemData['category'] ?? {})
              .values
              .toList()
              .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
              .toList(),
          targetOrigin: '*'),
    );

    WebPlugins().iframeElement(
      viewType: headOfHouseholdId,
      generatedHTML: generateAM5PieChartHtml(
          name: headOfHouseholdId,
          labels: (clientItemData['head of household'] ?? {})
              .keys
              .map((e) => e.toFirstUpper().splitCamelCase())
              .toList(),
          backgroundColor: [],
          data: (clientItemData['head of household'] ?? {})
              .values
              .toList()
              .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
              .toList(),
          targetOrigin: '*'),
    );

    WebPlugins().iframeElement(
      viewType: occupationStatusId,
      generatedHTML: generateAM5PieChartHtml(
          name: occupationStatusId,
          labels: (clientItemData['occupation status'] ?? {})
              .keys
              .map((e) => e.toFirstUpper().splitCamelCase())
              .toList(),
          backgroundColor: [],
          data: (clientItemData['occupation status'] ?? {})
              .values
              .toList()
              .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
              .toList(),
          targetOrigin: '*'),
    );

    WebPlugins().iframeElement(
      viewType: sourceId,
      generatedHTML: generateAM5PieChartHtml(
          name: sourceId,
          labels: (clientItemData['source of client'] ?? {})
              .keys
              .map((e) => e.toFirstUpper().splitCamelCase())
              .toList(),
          backgroundColor: [],
          data: (clientItemData['source of client'] ?? {})
              .values
              .toList()
              .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
              .toList(),
          targetOrigin: '*'),
    );

    WebPlugins().iframeElement(
      viewType: feeRangeId,
      generatedHTML: generateAM5PieChartHtml(
          sort: false,
          name: feeRangeId,
          innerRadius: 40,
          labels: ((itemData['dashBoardData']?["accountFeePercentage"] ?? {}) as Map)
              .keys
              .map(
                (e) => e?.toString() ?? '',
              )
              .toList(),
          backgroundColor: [],
          data: ((itemData['dashBoardData']?["accountFeePercentage"] ?? {}) as Map)
              .values
              .toList()
              .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
              .toList(),
          targetOrigin: '*'),
    );
    WebPlugins().iframeElement(
      viewType: feeRangeNameId,
      generatedHTML: generateAM5PieChartHtml(
          name: feeRangeNameId,
          innerRadius: 40,
          labels: ((itemData['dashBoardData']?["accountFeeName"] ?? {}) as Map)
              .keys
              .map(
                (e) => e?.toString() ?? '',
              )
              .toList(),
          backgroundColor: [],
          data: ((itemData['dashBoardData']?["accountFeeName"] ?? {}) as Map)
              .values
              .toList()
              .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
              .toList(),
          targetOrigin: '*'),
    );
    WebPlugins().iframeElement(
      viewType: ageBandId,
      generatedHTML: generateAM5PieChartHtml(
          sort: false,
          allowLegend: false,
          innerRadius: 50,
          name: ageBandId,
          semiCircle: true,
          labels: ((itemData['dashBoardData']?["ageRange"] ?? {}) as Map)
              .keys
              .toList()
              .map((e) => e.toString())
              .toList(),
          backgroundColor: [],
          data: ((itemData['dashBoardData']?["ageRange"] ?? {}) as Map)
              .values
              .toList()
              .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
              .toList(),
          targetOrigin: '*'),
    );
    WebPlugins().iframeElement(
      viewType: investmentStrategyId,
      generatedHTML: generateAM5PieChartHtml(
          name: investmentStrategyId,
          labels: ((itemData['dashBoardData']?['investmentObjective'] ?? {}) as Map)
              .keys
              .toList()
              .map((e) => e.toString())
              .toList(),
          backgroundColor: [],
          data: ((itemData['dashBoardData']?['investmentObjective'] ?? {}) as Map)
              .values
              .toList()
              .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
              .toList(),
          targetOrigin: '*'),
    );
    setState(() {
      loading = false;
    });
  }

  Future<void> updatePayHistory() async {
    List<AdvisorBalance> advisorBalances = [];
    SearchResult advisorBalanceResults = await searchGraphql(
      model: AdvisorBalance.classType,
      isMounted: () => true,
      nextToken: null,
      filter:
          'filter: {${AdvisorBalance.COMMPERIOD.fieldName}: {gte: "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-01", lt: "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-01"}}',
    );
    advisorBalances
        .addAll(advisorBalanceResults.items?.map((i) => AdvisorBalance.fromJson(i)).toList() ?? []);
    while (advisorBalanceResults.nextToken != null) {
      advisorBalanceResults = await searchGraphql(
        model: AdvisorBalance.classType,
        isMounted: () => true,
        nextToken: Uri.encodeComponent(advisorBalanceResults.nextToken ?? ""),
        filter:
            'filter: {${AdvisorBalance.COMMPERIOD.fieldName}: {gte: "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-01", lt: "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-01"}}',
      );
      advisorBalances.addAll(
          advisorBalanceResults.items?.map((i) => AdvisorBalance.fromJson(i)).toList() ?? []);
    }

    Map<String, double> payHistory = {};

    for (AdvisorBalance advisorBalance in advisorBalances
        .where((ab) => selectedUser?.advisorIds?.contains(ab.repOnTradeID) == true)) {
      DateTime? commPeriod = advisorBalance.commPeriod?.getDateTime();
      if (commPeriod != null) {
        String key =
            DateTime(commPeriod.year, commPeriod.month, 1).millisecondsSinceEpoch.toString();
        if (payHistory.containsKey(key)) {
          payHistory[key] = payHistory[key]! + (advisorBalance.payable ?? 0.0);
        } else {
          payHistory[key] = (advisorBalance.payable ?? 0.0);
        }
      }
    }
    itemData['payHistory'] = payHistory;

    WebPlugins().sendMessageToIframe(payHistoryId, {
      'type': 'updateChartData',
      'newData': itemData['payHistory']?.entries.map((e) {
            return {"date": double.parse(e.key), "value": (e.value as double).toInt()};
          }).toList() ??
          [],
    });
  }

  Map<String, Map<String, dynamic>> itemData = {};
  Map<String, Map<String, dynamic>> clientItemData = {};
  String investmentStrategyId = 'investmentStrategyHistory';
  String payHistoryId = 'containerPayHistory';
  String categoryId = 'containerCategory';
  String headOfHouseholdId = 'containerHeadOfHousehold';
  String occupationStatusId = 'containerOccupation';
  String sourceId = 'containerSource';
  String feeRangeId = 'containerFeeRange';
  String feeRangeNameId = 'containerFeeRangeName';
  String ageBandId = 'containerAgeBand';
  bool feeRangeToggle = false;
  bool togglePayHistory = false;

  Future<void> displayChartSelectionGrid(
    BuildContext context,
    String chartId,
  ) {
    List<String> accountIds = [investmentStrategyId, feeRangeId, feeRangeNameId, ageBandId];
    List<GridColumn> columns = [
      GridColumn(
          columnName: "Name",
          label: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: const Text(
              "Name",
              overflow: TextOverflow.ellipsis,
            ),
          )),
      GridColumn(
        columnName: "Number of ${accountIds.contains(chartId) ? "Account" : "Client"}",
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          alignment: Alignment.centerLeft,
          child: Text(
            "Number of ${accountIds.contains(chartId) ? "Account" : "Client"}",
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
    ];
    List<Map<String, dynamic>> itemsData = [
      {"Name": label, "Number of ${accountIds.contains(chartId) ? "Account" : "Client"}": count}
    ];

    ItemsDataSource items = ItemsDataSource(
      items: itemsData,
      columns: columns,
      model: (accountIds.contains(chartId) ? Account.classType : Client.classType) as ModelType,
      getRowsPerPage: rowsPerPage,
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => PointerInterceptor(
        child: AlertDialog(
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                height: 450,
                width: 600,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: 300,
                      child: SfDataGrid(
                        source: items,
                        columns: columns,
                        allowColumnsDragging: true,
                        allowColumnsResizing: true,
                        allowSorting: true,
                        allowFiltering: true,
                        columnResizeMode: ColumnResizeMode.onResizeEnd,
                        columnWidthMode: ColumnWidthMode.auto,
                        isScrollbarAlwaysShown: true,
                        onCellDoubleTap: (event) =>
                            {changeVisibility(), Navigator.of(context).pop()},
                        onColumnDragging: (DataGridColumnDragDetails details) {
                          if (details.action == DataGridColumnDragAction.dropped &&
                              details.to != null) {
                            final GridColumn rearrangeColumn = columns[details.from];
                            columns.removeAt(details.from);
                            columns.insert(details.to!, rearrangeColumn);
                            items.buildDataGridRows();
                          }
                          return true;
                        },
                        onColumnResizeUpdate: (ColumnResizeUpdateDetails args) {
                          List<GridColumn> tempColumns = [];
                          for (GridColumn column in columns) {
                            if (column.columnName == args.column.columnName) {
                              GridColumn(
                                columnName: column.columnName == 'null' ? "" : column.columnName,
                                width: args.width,
                                label: column.label,
                                allowFiltering: column.allowFiltering,
                                allowSorting: column.allowSorting,
                                autoFitPadding: column.autoFitPadding,
                                columnWidthMode: column.columnWidthMode,
                                filterIconPadding: column.filterIconPadding,
                                filterIconPosition: column.filterIconPosition,
                                filterPopupMenuOptions: column.filterPopupMenuOptions,
                                maximumWidth: column.maximumWidth,
                                minimumWidth: column.minimumWidth,
                                sortIconPosition: column.sortIconPosition,
                                visible: column.visible,
                              );
                            } else {
                              tempColumns.add(column);
                            }
                          }
                          columns = tempColumns;

                          return true;
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  int rowsPerPage({int? value}) {
    if (value != null) {
      setState(() {
        _rowsPerPage = value;
      });
    }
    return _rowsPerPage;
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : showingGrid
            ? hideDashboard
                ? Container()
                : Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_outlined),
                          onPressed: changeVisibility,
                        ),
                      ),
                      Expanded(
                        child: ExplorerGraphQL(
                          key: UniqueKey(),
                          model: (chartId == categoryId
                              ? client_model.Client.classType
                              : Account.classType) as ModelType<Model>,
                          insertCustomColumns: 5,
                          initialHiddenColumns: Account.schema.fields?.entries
                                  .where((e) => !accountColumnOrder.contains(e.key))
                                  .map((e) => e.key)
                                  .toList() ??
                              [],
                          initialChips: [
                            if (chartId == categoryId) "Category: $label",
                            if (chartId == headOfHouseholdId) "Head Of Household: $label",
                            if (chartId == feeRangeId) "Account Fee Percentage: $label",
                            if (chartId == feeRangeNameId) "Account Fee Name: $label",
                            if (chartId == ageBandId) "Birth Date: $label",
                            if (chartId == occupationStatusId) "Occupation Status: $label",
                            if (chartId == sourceId) "Source Of Client: $label",
                            if (chartId == investmentStrategyId) "Investment Objective: $label",
                            "${Account.CLIENTSTATUS.fieldName.toFirstUpper().splitCamelCase()}: ${AccountClientStatusEnum.Active.name}",
                          ],
                          initialColumnOrder: accountColumnOrder,
                          persistChips: false,
                        ),
                      ),
                    ],
                  )
            : hideDashboard
                ? Container()
                : Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 24,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Good ${getGreeting()}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontSize: 24),
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      setState(() {
                                        selectedUser =
                                            widget.users.firstWhereOrNull((u) => u.id == value);
                                      });
                                      await loadData();
                                    },
                                    tooltip: selectedUser?.email ?? "",
                                    enabled: widget.users.length > 1,
                                    itemBuilder: (context) {
                                      List<PopupMenuItem<String>> items = [];
                                      for (User user in widget.users) {
                                        items.add(
                                          PopupMenuItem(
                                            value: user.id,
                                            child: Text(user.email ?? ""),
                                          ),
                                        );
                                      }
                                      return items;
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.person_outline),
                                        Icon(Icons.arrow_drop_down_outlined),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(
                                height: 24,
                              ),
                              Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(
                                        maxHeight: 338, maxWidth: 650, minHeight: 338),
                                    child: DashboardCardFlip(
                                      title: "Pay History - ${selectedUser?.email}",
                                      toogleCard: () => setState(() {
                                        togglePayHistory = !togglePayHistory;
                                      }),
                                      icon: Icon(togglePayHistory
                                          ? Icons.flip_outlined
                                          : Icons.settings_outlined),
                                      children: [
                                        togglePayHistory
                                            ? Center(
                                                child: AdaptiveGrid(
                                                  minimumWidgetWidth: 200,
                                                  children: [
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          startDate =
                                                              subtractMonths(DateTime.now(), 6);
                                                          endDate = DateTime.parse(
                                                              "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-01");
                                                        });
                                                        updatePayHistory();
                                                      },
                                                      child: const Text("6 Months"),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          startDate =
                                                              subtractMonths(DateTime.now(), 12);
                                                          endDate = DateTime.parse(
                                                              "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-01");
                                                        });
                                                        updatePayHistory();
                                                      },
                                                      child: const Text("1 Year"),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          startDate =
                                                              subtractMonths(DateTime.now(), 36);
                                                          endDate = DateTime.parse(
                                                              "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-01");
                                                        });
                                                        updatePayHistory();
                                                      },
                                                      child: const Text("3 Year"),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          startDate =
                                                              subtractMonths(DateTime.now(), 60);
                                                          endDate = DateTime.parse(
                                                              "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-01");
                                                        });
                                                        updatePayHistory();
                                                      },
                                                      child: const Text("5 Year"),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          hideDashboard = true;
                                                        });
                                                        showDateRangePicker(
                                                          context: context,
                                                          firstDate: DateTime.now()
                                                              .add(const Duration(days: -365000)),
                                                          lastDate: DateTime.now(),
                                                        ).then((dateRange) {
                                                          if (mounted) {
                                                            setState(() {
                                                              hideDashboard = false;
                                                              startDate = dateRange?.start ??
                                                                  DateTime.now();
                                                              endDate =
                                                                  dateRange?.end ?? DateTime.now();
                                                            });
                                                            updatePayHistory();
                                                          }
                                                        });
                                                      },
                                                      child: const Text("Custom Date Range"),
                                                    )
                                                  ],
                                                ),
                                              )
                                            : Container(
                                                constraints: const BoxConstraints(
                                                    maxHeight: 254, maxWidth: 685),
                                                child: const HtmlElementView(
                                                  viewType: "containerPayHistory",
                                                ),
                                              )
                                      ],
                                    ),
                                  ),
                                  ChartsWidget(
                                    maxWidth: 650,
                                    viewId: categoryId,
                                    title: "Category",
                                  ),
                                  Container(
                                    constraints: const BoxConstraints(
                                        maxHeight: 340, maxWidth: 650, minHeight: 328),
                                    child: DashboardCardFlip(
                                      toogleCard: () => setState(() {
                                        feeRangeToggle = !feeRangeToggle;
                                      }),
                                      title:
                                          feeRangeToggle ? "Flat Fee Range Name" : "Flat Fee Range",
                                      children: [
                                        Container(
                                          constraints:
                                              const BoxConstraints(maxHeight: 264.5, maxWidth: 685),
                                          child: HtmlElementView(
                                            viewType: feeRangeToggle
                                                ? "containerFeeRangeName"
                                                : "containerFeeRange",
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ChartsWidget(
                                    maxWidth: 650,
                                    viewId: investmentStrategyId,
                                    title: "Investment Strategy",
                                  ),
                                  ChartsWidget(
                                    maxWidth: 650,
                                    viewId: ageBandId,
                                    title: "Age Bands",
                                  ),
                                  ChartsWidget(
                                    maxWidth: 650,
                                    viewId: headOfHouseholdId,
                                    title: "Head of Household",
                                  ),
                                  ChartsWidget(
                                    maxWidth: 650,
                                    viewId: occupationStatusId,
                                    title: "Occupation",
                                  ),
                                  ChartsWidget(
                                    maxWidth: 650,
                                    viewId: sourceId,
                                    title: "Source of Client",
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
  }
}

class ChartsWidget extends StatefulWidget {
  const ChartsWidget({
    super.key,
    required this.viewId,
    required this.title,
    this.maxWidth = 450,
    this.actions = const [],
  });
  final String title;
  final String viewId;
  final double maxWidth;
  final List<Widget> actions;

  @override
  State<ChartsWidget> createState() => _ChartsWidgetState();
}

class _ChartsWidgetState extends State<ChartsWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: 390, maxWidth: widget.maxWidth),
      child: Card(
        elevation: 5,
        shadowColor: Theme.of(context).textTheme.labelLarge?.color,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdaptiveGrid(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      widget.title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (widget.actions.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: PopupMenuButton(
                        itemBuilder: (context) {
                          List<PopupMenuItem> popupMenuItems = [
                            for (Widget action in widget.actions) PopupMenuItem(child: action)
                          ];
                          return popupMenuItems;
                        },
                      ),
                    )
                ],
              ),
              Container(
                  constraints: BoxConstraints(maxHeight: 264, maxWidth: widget.maxWidth),
                  child: HtmlElementView(viewType: widget.viewId)),
            ],
          ),
        ),
      ),
    );
  }
}
