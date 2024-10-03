import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/Account.dart';
import 'package:base/models/Client.dart' as clientModel;
import 'package:base/models/AccountClientStatusEnum.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/providers/auth_state.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:payouts/router_payouts.dart';
import 'package:rms/view/explore/explorer_graphql.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class FeeChange extends StatefulWidget {
  final ModelType<Model> model;
  const FeeChange({super.key, required this.model});

  @override
  State<FeeChange> createState() => _FeeChangeState();
}

class _FeeChangeState extends State<FeeChange> {
  DataGridRow? dataGridRow;
  final _formKey = GlobalKey<FormState>();
  String _radioValue = 'Blended';
  String? _signature1, _signature2, _signature3;

  @override
  Widget build(BuildContext context) {
    return dataGridRow != null
        ? SingleChildScrollView(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                                onPressed: () => setState(() {
                                      dataGridRow = null;
                                    }),
                                icon: const Icon(Icons.arrow_back_outlined)),
                            Text(dataGridRow
                                    ?.getCells()
                                    .firstWhereOrNull((c) =>
                                        c.columnName ==
                                        Account.EXTERNALACCOUNT.fieldName
                                            .toFirstUpper()
                                            .splitCamelCase())
                                    ?.value
                                    ?.toString() ??
                                "")
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        TextFormField(
                          initialValue: dataGridRow
                                  ?.getCells()
                                  .firstWhereOrNull((c) =>
                                      c.columnName ==
                                      Account.ACCOUNTFEEPERCENTAGE.fieldName
                                          .toFirstUpper()
                                          .splitCamelCase())
                                  ?.value
                                  ?.toString() ??
                              "",
                          decoration:
                              const InputDecoration(labelText: 'Current Fee'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter some text';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'New Fee'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter some text';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Wrap(
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'Blended',
                                        groupValue: _radioValue,
                                        onChanged: (value) {
                                          setState(() {
                                            _radioValue = value!;
                                          });
                                        },
                                      ),
                                      const Text('Blended'),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'Tiered',
                                        groupValue: _radioValue,
                                        onChanged: (value) {
                                          setState(() {
                                            _radioValue = value!;
                                          });
                                        },
                                      ),
                                      const Text('Tiered'),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'Flat',
                                        groupValue: _radioValue,
                                        onChanged: (value) {
                                          setState(() {
                                            _radioValue = value!;
                                          });
                                        },
                                      ),
                                      const Text('Flat'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Fee Change Reason',
                          ),
                          maxLength: 500,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter some text';
                            }
                            return null;
                          },
                        ),
                        if (AuthState().groups?.contains("rms") ?? false) ...[
                          TextFormField(
                            decoration: const InputDecoration(
                                labelText: 'Compliance Signature'),
                            onSaved: (value) {
                              _signature1 = value;
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your signature';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            decoration: const InputDecoration(
                                labelText: 'Compensation Signature'),
                            onSaved: (value) {
                              _signature2 = value;
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your signature';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            decoration: const InputDecoration(
                                labelText: 'Executive Signature'),
                            onSaved: (value) {
                              _signature3 = value;
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your signature';
                              }
                              return null;
                            },
                          )
                        ],
                        const SizedBox(
                          height: 10,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Form Submitted')),
                              );
                            }
                          },
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : ExplorerGraphQL(
            addItemOptions: (
                {required itemOptions, required model, required selectedRows}) {
              if (model == Account.classType &&
                  (AuthState().groups?.contains("payouts") ?? false)) {
                itemOptions.add(IconButton(
                    onPressed: selectedRows.length == 1
                        ? () {
                            setState(() {
                              dataGridRow = selectedRows.first;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.money_outlined)));
              }
            },
            allowActions: true,
            insertCustomColumns: widget.model.modelName() == Account.schema.name
                ? 5
                : widget.model.modelName() == clientModel.Client.schema.name
                    ? 3
                    : null,
            model: widget.model,
            initialHiddenColumns: widget.model.modelName() ==
                    Account.schema.name
                ? Account.schema.fields?.entries
                        .where((e) => !accountColumnOrder.contains(e.key))
                        .map((e) => e.key)
                        .toList() ??
                    []
                : widget.model.modelName() == clientModel.Client.schema.name
                    ? clientModel.Client.schema.fields?.entries
                            .where((e) => !clientColumnOrder.contains(e.key))
                            .map((e) => e.key)
                            .toList() ??
                        []
                    : [],
            initialChips: widget.model == Account.classType
                ? [
                    "${Account.CLIENTSTATUS.fieldName.toFirstUpper().splitCamelCase()}: ${AccountClientStatusEnum.Active.name}",
                  ]
                : widget.model == Client.classType
                    ? [
                        "${Client.CLIENTSTATUS.fieldName.toFirstUpper().splitCamelCase()}: ${AccountClientStatusEnum.Active.name}",
                      ]
                    : [],
            initialOrChips: widget.model == Account.classType
                ? [
                    Account.EXTERNALACCOUNT.fieldName
                        .toFirstUpper()
                        .splitCamelCase(),
                    Account.DISPLAYNAME1.fieldName
                        .toFirstUpper()
                        .splitCamelCase(),
                  ]
                : widget.model == Client.classType
                    ? [
                        Client.LASTNAME.fieldName
                            .toFirstUpper()
                            .splitCamelCase(),
                        "Referred By"
                      ]
                    : [],
            initialColumnOrder: widget.model.modelName() == Account.schema.name
                ? accountColumnOrder
                : widget.model.modelName() == clientModel.Client.schema.name
                    ? clientColumnOrder
                    : null,
          );
  }
}
