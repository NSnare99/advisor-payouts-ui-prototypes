import 'dart:convert';

import 'package:base/models/User.dart';
import 'package:base/providers/auth_state.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:base/views/root_layout.dart';
import 'package:flutter/material.dart';
import 'package:payouts/router_payouts.dart';
import 'package:payouts/view/dashboards/dashboard.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';

class PayoutsHomeScreen extends StatefulWidget {
  const PayoutsHomeScreen({super.key, required this.scaffoldKey});
  final LocalKey? scaffoldKey;

  @override
  State<PayoutsHomeScreen> createState() => _PayoutsHomeScreenState();
}

class _PayoutsHomeScreenState extends State<PayoutsHomeScreen> {
  bool loadingAdvisors = false;
  bool onSelectionFInished = true;
  List<User> users = [];

  @override
  void initState() {
    _getAdvisorsAndSplits();
    super.initState();
  }

  Future<void> _getAdvisorsAndSplits() async {
    setState(() {
      loadingAdvisors = true;
    });

    List<String>? groups = AuthState().groups;
    if ([...?AuthState().groups].contains("rms")) {
      SearchResult usersResult = await searchGraphql(
        model: User.classType,
        isMounted: () => mounted,
        nextToken: null,
      );
      users = usersResult.items
              ?.map(User.fromJson)
              .where((u) => u.advisorIds != null && u.advisorIds != [])
              .toList() ??
          [];
      while (usersResult.nextToken != null) {
        usersResult = await searchGraphql(
          model: User.classType,
          isMounted: () => mounted,
          nextToken: Uri.encodeComponent(usersResult.nextToken ?? ""),
        );
        users.addAll(
          usersResult.items
                  ?.map(User.fromJson)
                  .where((u) => u.advisorIds != null && u.advisorIds != [])
                  .toList() ??
              [],
        );
      }
    } else {
      List<Future> futures = [];
      if (groups != null) {
        for (String group in groups) {
          String query = '''
      query _ {
        get${User.schema.name}(${User.ID.fieldName}: "$group") {
          ${generateGraphqlQueryFields(schema: User.schema)}
        }
      }''';
          futures.add(
            gqlQuery(query).then((result) {
              Map? resultMap = jsonDecode(result.body) is Map
                  ? ((jsonDecode(result.body) as Map)['data']?['get${User.schema.name}'])
                  : null;
              if (resultMap != null &&
                  resultMap.containsKey(User.ID.fieldName) &&
                  resultMap.containsKey(User.EMAIL.fieldName) &&
                  resultMap.containsKey(User.ADVISORIDS.fieldName) &&
                  resultMap[User.ADVISORIDS.fieldName] != null &&
                  resultMap[User.ADVISORIDS.fieldName] != []) {
                users.add(User.fromJson(Map<String, dynamic>.from(resultMap)));
              }
            }),
          );
        }
      }
      await Future.wait(futures);
    }
    users.sort((a, b) => a.email?.compareTo(b.email ?? "") ?? 0);
    setState(() {
      loadingAdvisors = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RootLayout(
      key: widget.scaffoldKey,
      destinations: payoutsDestinations,
      currentIndex: 1,
      child: loadingAdvisors
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Dashboard(users: users),
    );
  }
}
