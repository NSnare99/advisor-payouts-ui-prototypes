import 'dart:convert';
import 'package:base/models/Advisor.dart';
import 'package:base/providers/app_state.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:rms/view/report_generation/report_downloader.dart';
import 'package:rms/view/report_generation/report_generator.dart';
import 'package:rms/view/upload/upload_steps/custom_stepper.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

//To add new reports in UI, add option
//to enum. When sending the request to generate
//the report, the name of the enum choice is sent to
//the lambda function (ptolemyReportEngine).
enum Report { feeCommissionStatement }

class ReportSteps extends StatefulWidget {
  const ReportSteps({super.key});

  @override
  State<ReportSteps> createState() => _ReportStepsState();
}

class _ReportStepsState extends State<ReportSteps> {
  late Map<String, dynamic> _pdfData;

  //Selection of specific report
  late Report selectedReport;
  late String selectedReportName;
  late List<String> reportNameOptions;
  late Map<String, Report> reportNameToReportEnum;
  late Advisor selectedAdvisor;
  List<Advisor> advisors = [];
  bool loadingAdvisors = false;
  String idSelection = "";
  int statementProgressPercentage = 0;
  String statementProgressMessage = "";

  //Filters for gql query
  DateTime startDate = DateUtils.dateOnly(DateTime.now());
  TextEditingController controller = TextEditingController();

  //Variables for report download
  bool isDownloadingPDF = false;

  bool isGeneratingReport = false;
  bool isValidStatementDate = true;

  Future<void> _getAdvisorsAndSplits() async {
    setState(() {
      loadingAdvisors = true;
    });
    SearchResult advisorResults = await searchGraphql(
      model: Advisor.classType,
      isMounted: () => true,
      nextToken: null,
    );
    advisors.addAll(
        advisorResults.items?.map((a) => Advisor.fromJson(a)).toList() ?? []);
    while (advisorResults.nextToken != null) {
      advisorResults = await searchGraphql(
        model: Advisor.classType,
        isMounted: () => true,
        nextToken: Uri.encodeComponent(advisorResults.nextToken ?? ""),
      );
      advisors.addAll(
          advisorResults.items?.map((a) => Advisor.fromJson(a)).toList() ?? []);
    }

    setState(() {
      advisors = advisors.sorted((a, b) =>
          '${a.firstName} ${a.lastName} (${a.id})'
              .compareTo('${b.firstName} ${b.lastName} (${b.id})'));
      loadingAdvisors = false;
      idSelection = advisors.first.id;
    });
  }

  @override
  void initState() {
    _getAdvisorsAndSplits();
    super.initState();
    reportNameOptions = [];
    reportNameToReportEnum = {};
    //Based on enum values, generate UI components for report selection
    for (var value in Report.values) {
      String reportAsString = value.name.splitCamelCase();
      reportNameOptions.add(reportAsString);
      reportNameToReportEnum[reportAsString] = value;
    }
    //Set selected report to the first value in list
    selectedReportName = reportNameOptions[0];
    selectedReport = reportNameToReportEnum[selectedReportName]!;
  }

  void toggleReportGenState() {
    setState(() {
      isDownloadingPDF = !isDownloadingPDF;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppStateManager appStateManager = Provider.of<AppStateManager>(context);
    List<StepContent> steps = [
      StepContent(
        title: "Select Statement Date Range",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return LayoutBuilder(
            builder: (context, BoxConstraints constraints) {
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 10, 0, 30),
                    child: Wrap(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(
                          width: 18.0,
                        ),
                        Text(
                          "Enter the date range for the report to filter by.",
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: constraints.minWidth > 730
                        ? 400
                        : constraints.minWidth * .60,
                    child: Card(
                      surfaceTintColor: Theme.of(context).colorScheme.surface,
                      elevation: 20,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 60, 10, 60),
                        child: SizedBox(
                            width: constraints.maxWidth * .4,
                            child: TextFormField(
                              initialValue:
                                  DateFormat('yyyy-MM-dd').format(startDate),
                              decoration: const InputDecoration(
                                icon: Icon(Icons.date_range),
                                labelText: 'Enter Statement Date',
                              ),
                              onChanged: (value) {
                                try {
                                  DateTime start =
                                      DateTime.parse(dateSeparator(value));
                                  setState(() {
                                    isValidStatementDate = true;
                                    startDate = start;
                                  });
                                } catch (e) {
                                  setState(() {
                                    isValidStatementDate = false;
                                  });
                                }
                              },
                            )),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(),
                  ),
                  Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.all(15.0),
                    child: ElevatedButton(
                      onPressed: isDisabled || !isValidStatementDate
                          ? null
                          : completeStep,
                      child: Text("Next Step"),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      StepContent(
        title: "Select Advisor For Report",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return LayoutBuilder(
            builder: (context, BoxConstraints constraints) {
              return isGeneratingReport
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 100,
                            width: 100,
                            child: CircularProgressIndicator(),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                                "$statementProgressMessage: $statementProgressPercentage%"),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(0, 10, 0, 30),
                          child: Wrap(
                            children: [
                              Icon(Icons.info_outline),
                              SizedBox(
                                width: 18.0,
                              ),
                              Text(
                                "Select Advisor on Statement",
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: constraints.minWidth > 730
                              ? 600
                              : constraints.minWidth * .60,
                          child: Card(
                            surfaceTintColor:
                                Theme.of(context).colorScheme.surface,
                            elevation: 20,
                            child: Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 60, 0, 60),
                                  child: DropdownMenu<Advisor>(
                                    label: const Text("Advisor Selection"),
                                    initialSelection: advisors.first,
                                    onSelected: (value) async {
                                      setState(() {
                                        selectedAdvisor =
                                            value ?? advisors.first;
                                        idSelection = value == null
                                            ? advisors.first.id
                                            : value.id;
                                      });
                                    },
                                    dropdownMenuEntries: advisors
                                        .map((advisor) => DropdownMenuEntry(
                                            value: advisor,
                                            label:
                                                '${advisor.firstName} ${advisor.lastName} (${advisor.id})'))
                                        .toList(),
                                    enabled: advisors.length > 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(),
                        ),
                        Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.all(15.0),
                          child: ElevatedButton(
                            onPressed: isDisabled
                                ? null
                                : () async {
                                    setState(() {
                                      isGeneratingReport = true;
                                    });
                                    Map<String, dynamic> reportData =
                                        await generatePDFReportData(
                                      {
                                        "repId": idSelection,
                                        "startDate": DateFormat('yyyy-MM-dd')
                                            .format(startDate),
                                        "endDate": DateFormat('yyyy-MM-dd')
                                            .format(startDate),
                                      },
                                      selectedReport.name,
                                      ({
                                        required String progressMessage,
                                        required int progressPercentage,
                                      }) {
                                        setState(() {
                                          statementProgressMessage =
                                              progressMessage;
                                          statementProgressPercentage =
                                              progressPercentage;
                                        });
                                      },
                                    );

                                    setState(() {
                                      isGeneratingReport = false;
                                      _pdfData = reportData;
                                    });
                                    completeStep();
                                  },
                            child: Text("Next Step"),
                          ),
                        ),
                      ],
                    );
            },
          );
        },
      ),
      StepContent(
        title: "Preview Statement",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return Column(
            children: [
              isDownloadingPDF
                  ? const CircularProgressIndicator()
                  : _pdfData.isEmpty
                      ? const Center(
                          child: Text("No Data To Display"),
                        )
                      : OutlinedButton(
                          onPressed: () async {
                            toggleReportGenState();
                            await downloadReportPdfFile(
                              contentType: _pdfData["contentType"]!,
                              dataURI: _pdfData["dataURI"]!,
                              fileName: _pdfData["fileName"]!,
                            );
                            toggleReportGenState();
                          },
                          child: const Text("Download Report"),
                        ),
              Expanded(
                //Send pdf memory data to viewer
                child: SfPdfViewer.memory(
                  base64Decode(_pdfData["dataURI"]!),
                ),
              ),
            ],
          );
        },
      ),
      StepContent(
        title: "Download Report",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return Column(
            children: [
              isDownloadingPDF
                  ? const CircularProgressIndicator()
                  : _pdfData.isEmpty
                      ? const Center(
                          child: Text("No Data To Display"),
                        )
                      : OutlinedButton(
                          onPressed: () async {
                            toggleReportGenState();
                            await downloadReportPdfFile(
                              contentType: _pdfData["contentType"]!,
                              dataURI: _pdfData["dataURI"]!,
                              fileName: _pdfData["fileName"]!,
                            );
                            toggleReportGenState();
                          },
                          child: const Text("Download Report"),
                        ),
              Expanded(
                //Send pdf memory data to viewer
                child: SfPdfViewer.memory(
                  base64Decode(_pdfData["dataURI"]!),
                ),
              ),
            ],
          );
        },
      ),
    ];

    if (!appStateManager.showUploaderIntro) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(),
          Column(
            children: [
              Text(
                "Statement Generator",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(
                height: 25,
              ),
              Text(
                "Select 'Begin Workflow' to generate your statement.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(
                height: 25,
              ),
              OutlinedButton(
                onPressed: () => {appStateManager.viewedUploaderIntro()},
                child: const Text('Begin Workflow'),
              ),
            ],
          ),
          Container(),
        ],
      );
    }

    return CustomStepper(steps: steps);
  }
}

String dateSeparator(String inputDateString) {
  List<String> dateAsList = [];
  inputDateString = inputDateString.trim();
  if (inputDateString.contains('-')) {
    dateAsList = inputDateString.split('-');
  } else if (inputDateString.contains('\\')) {
    dateAsList = inputDateString.split('\\');
  } else if (inputDateString.contains('/')) {
    dateAsList = inputDateString.split('/');
  } else {
    dateAsList = ["", "", ""];
  }
  if (dateAsList.length != 3) {
    dateAsList = ["", "", ""];
  }

  if (dateAsList[0].length == 4) {
    inputDateString = "${dateAsList[0]}-${dateAsList[1]}-${dateAsList[2]}";
  } else {
    inputDateString = "${dateAsList[2]}-${dateAsList[0]}-${dateAsList[1]}";
  }

  return inputDateString;
}
