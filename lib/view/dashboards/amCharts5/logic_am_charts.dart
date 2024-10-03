import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:collection/collection.dart';

Future<Map<String, Map<String, dynamic>>> processCustomFieldEnum({
  required List<TableField> tableFields,
  required List<TableFieldOption> tableFieldOptions,
  required List<Map<String, dynamic>> items,
  required User? selectedUser,
}) async {
  Map<String, Map<String, dynamic>> result = {};
  for (TableField tableField in tableFields.where((tf) => tf.fieldName != null)) {
    result[tableField.fieldName?.toLowerCase() ?? ""] = {};
    for (TableFieldOption tableFieldOption in tableFieldOptions
        .where((o) => o.tableFieldOptionsId == tableField.id && o.labelText != null)) {
      result[tableField.fieldName?.toLowerCase() ?? ""]
          ?[tableFieldOption.labelText?.toLowerCase() ?? ''] = "0";
    }
  }
  for (Map<String, dynamic> item in items) {
    if (item.containsKey("customFields")) {
      Map itemCustomField = jsonDecode(
          item['customFields'] != '' && item['customFields'] != null ? item['customFields'] : "{}");
      for (String customFieldKey in itemCustomField.keys) {
        TableField? customFieldTableField =
            tableFields.firstWhereOrNull((tf) => tf.id == customFieldKey) ??
                tableFields.firstWhereOrNull(
                  (tf) => tf.fieldName?.toLowerCase() == customFieldKey.toLowerCase(),
                );
        if ((customFieldKey == customFieldTableField?.id ||
                !itemCustomField.keys.contains(customFieldTableField?.id)) &&
            customFieldTableField?.fieldType == TableFieldFieldTypeEnum.SingleSelect) {
          Map optionsItemCustomField = itemCustomField[customFieldKey];
          if (optionsItemCustomField.containsKey(selectedUser?.id)) {
            result[customFieldTableField?.fieldName?.toLowerCase()]
                    ?[optionsItemCustomField[selectedUser?.id].toString().toLowerCase()] =
                ((int.tryParse(result[customFieldTableField?.fieldName?.toLowerCase()]?[
                                optionsItemCustomField[selectedUser?.id]
                                    .toString()
                                    .toLowerCase()]) ??
                            0) +
                        1)
                    .toString();
          }
        }
      }
    }
  }
  return result;
}

Future<Map<String, Map<String, dynamic>>> processDashboard(
    {required List<Map<String, dynamic>> items}) async {
  Map<String, Map<String, dynamic>> result = {};
  Map<String, int> feeResult = {
    "0%": 0,
    "0.01%-0.50%": 0,
    "0.51%-0.75%": 0,
    "0.76%-1.00%": 0,
    "1.01%-1.25%": 0,
    "1.26%-1.50%": 0,
    "1.51% and Up": 0,
    "Others": 0,
  };
  Map<String, int> ageResult = {
    "0-30": 0,
    "31-40": 0,
    "41-50": 0,
    "51-60": 0,
    "61-70": 0,
    "81 and Up": 0,
  };
  Map<String, int> nameResult = {};
  Map<String, int> investmentObjectiveResult = {};
  for (Map<String, dynamic> item in items) {
    if (item.containsKey("accountFeePercentage") &&
        item['accountFeePercentage']?.toString().trim() != '') {
      double? intValue =
          item['accountFeePercentage'] is double || item['accountFeePercentage'] is int
              ? double.tryParse(item['accountFeePercentage']?.toString() ?? "")
              : null;
      if (intValue != null) {
        if (intValue <= 0) {
          feeResult["0%"] = feeResult["0%"] == null ? 1 : feeResult["0%"]! + 1;
        } else if (intValue <= 0.5) {
          feeResult["0.01%-0.50%"] =
              feeResult["0.01%-0.50%"] == null ? 1 : feeResult["0.01%-0.50%"]! + 1;
        } else if (intValue <= 0.75) {
          feeResult["0.51%-0.75%"] =
              feeResult["0.51%-0.75%"] == null ? 1 : feeResult["0.51%-0.75%"]! + 1;
        } else if (intValue <= 1) {
          feeResult["0.76%-1.00%"] =
              feeResult["0.76%-1.00%"] == null ? 1 : feeResult["0.76%-1.00%"]! + 1;
        } else if (intValue <= 1.25) {
          feeResult["1.01%-1.25%"] =
              feeResult["1.01%-1.25%"] == null ? 1 : feeResult["1.01%-1.25%"]! + 1;
        } else if (intValue <= 1.50) {
          feeResult["1.26%-1.50%"] =
              feeResult["1.26%-1.50%"] == null ? 1 : feeResult["1.26%-1.50%"]! + 1;
        } else if (intValue > 1.50) {
          feeResult["1.51% and Up"] =
              feeResult["1.51% and Up"] == null ? 1 : feeResult["1.51% and Up"]! + 1;
        }
      }
    } else {
      feeResult["Others"] = feeResult["Others"] == null ? 1 : feeResult["Others"]! + 1;
    }
    if (item.containsKey("accountFeeName") && item['accountFeeName']?.toString().trim() != '') {
      String value = item['accountFeeName']?.toString().trim() ?? "";
      if (!nameResult.containsKey(value)) {
        nameResult[value] = 1;
      } else {
        nameResult[value] = nameResult[value]! + 1;
      }
    }
    if (item.containsKey("investmentObjective") &&
        item['investmentObjective']?.toString().trim() != '') {
      String value = item['investmentObjective']?.toString().trim() ?? "";
      if (!investmentObjectiveResult.containsKey(value)) {
        investmentObjectiveResult[value] = 1;
      } else {
        investmentObjectiveResult[value] = investmentObjectiveResult[value]! + 1;
      }
    }
    if (item.containsKey("birthDate")) {
      //&& item['birthDate']?.toString().trim() != ''
      DateTime? dateValue = DateTime.tryParse(item['birthDate']?.toString().trim() ?? "");
      // DateTime? dateValue2 = DateTime.tryParse(item['birthDate2']?.toString().trim() ?? "");
      // if (dateValue != null && dateValue2 != null && dateValue2.compareTo(dateValue) < 0) {
      //   dateValue = dateValue2;
      // }
      if (dateValue == null) continue;
      Duration parse = DateTime.now().difference(dateValue).abs();
      int years = parse.inDays ~/ 364.5;
      if (years < 30) {
        ageResult["0-30"] = ageResult["0-30"] == null ? 1 : ageResult["0-30"]! + 1;
      } else if (years < 40) {
        ageResult["31-40"] = ageResult["31-40"] == null ? 1 : ageResult["31-40"]! + 1;
      } else if (years < 50) {
        ageResult["41-50"] = ageResult["41-50"] == null ? 1 : ageResult["41-50"]! + 1;
      } else if (years < 60) {
        ageResult["51-60"] = ageResult["51-60"] == null ? 1 : ageResult["51-60"]! + 1;
      } else if (years < 70) {
        ageResult["61-70"] = ageResult["61-70"] == null ? 1 : ageResult["61-70"]! + 1;
      } else if (years < 80) {
        ageResult["71-80"] = ageResult["71-80"] == null ? 1 : ageResult["71-80"]! + 1;
      } else if (years > 80) {
        ageResult["81 and Up"] = ageResult["81 and Up"] == null ? 1 : ageResult["81 and Up"]! + 1;
      }
    }
  }
  result["accountFeePercentage"] = feeResult;
  result["accountFeeName"] = nameResult;
  result["investmentObjective"] = investmentObjectiveResult;
  result["ageRange"] = ageResult;
  return result;
}
