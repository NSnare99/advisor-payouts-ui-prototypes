import 'package:base/utilities/models/reports_classes.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:payouts/view/statement_generation/statement_section_generator.dart';
import 'package:rms/view/report_generation/report_downloader.dart';
import 'package:path/path.dart' as path;

Future<Map<String, dynamic>> generatePDFReportData() async {
  String fileName = "reportTemplate.pptx";

  await apiGatewayPOST(
    server: Uri.parse("$endpoint/powerpoint"),
    payload: ReplacementsPayload(
      convertToPDF: true,
      fileKey: fileName,
      groupId: "test",
      //dynamically find appropriate report template
      templateName: "feeCommissionStatementReportTemplate.pptx",
      replacementList: [
        Replacement(
          keyword: "_SECTIONS_",
          data: SectionReplacementData(
            separated: true,
            //Create sections based on report
            sections: sectionsCreatorStatement(),
          ),
          type: "section",
        ),
      ],
    ).toJson(),
  );

  //Generate PDF
  await apiGatewayPOST(
    server: Uri.parse("$endpoint/pdf"),
    payload: {"fileName": fileName},
  );

  Map<String, String> reportPDFData = await getPdfData(
    fileName: path.basename(fileName).replaceAll(".pptx", ".pdf"),
  );

  return reportPDFData;
}
