import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/User.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/files/file_upload_page.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:payouts/view/files/bread_crumbs.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:web_plugins/web_plugins.dart';

class Files extends StatefulWidget {
  const Files({super.key});

  @override
  State<Files> createState() => _FilesState();
}

class _FilesState extends State<Files> {
  bool loadingFiles = true;
  FileListResponse? fileListResponse;
  String requestSource = "storage";
  String folder = "files";
  List<String> breadCrumbs = [];
  List<User> users = [];
  User? selectedUser;
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    breadCrumbs.add(requestSource);
    _getUsers();
    super.initState();
  }

  Future<void> _getFiles() async {
    if (mounted) {
      setState(() {
        loadingFiles = true;
      });
    }
    Response response = await apiGatewayGET(
      server: Uri.parse("$endpoint/file"),
      queryParameters: {
        "requestType": "list",
        "requestSource": requestSource,
        "folder": ["files", "storage", "recieved", "deleted"].contains(folder)
            ? ""
            : folder,
        if (selectedUser != null) "otherUser": selectedUser?.id,
      },
    );
    var jsonReponse = jsonDecode(response.body);

    List<S3ItemAttributes> itemsList = jsonReponse['items'] is List
        ? (jsonReponse['items'] as List)
            .map(
              (i) => getS3ItemAttributesFromFileInfo(S3Item.fromJson(i)),
            )
            .toList()
        : [];

    if (itemsList.every((item) => item.startDate != null)) {
      itemsList.sort((a, b) {
        int dateComparison = -(DateTime.parse(a.startDate!)
            .compareTo(DateTime.parse(b.startDate!)));

        if (dateComparison == 0) {
          if (a.repId != null && b.repId != null) {
            return a.repId!.compareTo(b.repId!);
          }
        }
        return dateComparison;
      });
    }

    fileListResponse = FileListResponse(
        items: itemsList,
        folders: jsonReponse['folders'] is List
            ? (jsonReponse['folders'] as List)
                .map((i) => S3Folder.fromJson(i))
                .toList()
            : []);

    if (mounted) {
      setState(() {
        loadingFiles = false;
      });
    }
  }

  Future<void> _getUsers() async {
    if (mounted) {
      setState(() {
        loadingFiles = true;
        users = [];
      });
    }
    SearchResult userResult = await searchGraphql(
      model: User.classType,
      isMounted: () => mounted,
      nextToken: null,
    );
    users.addAll(userResult.items
            ?.map(User.fromJson)
            .where((u) => u.advisorIds != null)
            .toList() ??
        []);
    while (userResult.nextToken != null) {
      userResult = await searchGraphql(
        model: User.classType,
        isMounted: () => mounted,
        nextToken: Uri.encodeComponent(userResult.nextToken ?? ""),
      );
      users.addAll(userResult.items
              ?.map(User.fromJson)
              .where((u) => u.advisorIds != null)
              .toList() ??
          []);
    }
    if (mounted) {
      setState(() {
        loadingFiles = false;
        selectedUser = users.isNotEmpty ? users.first : null;
      });
    }
    await _getFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: AppBarTheme.of(context).toolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Breadcrumbs(
                    items: breadCrumbs,
                    onTap: (index) async {
                      // Keep only the items up to the clicked breadcrumb
                      breadCrumbs.removeRange(index + 1, breadCrumbs.length);
                      // You should call setState to rebuild the UI after modifying the list
                      if (mounted) {
                        folder = breadCrumbs.last;
                      }
                      await _getFiles();
                    },
                  ),
                  users.isNotEmpty
                      ? PopupMenuButton(
                          icon: const Icon(Icons.arrow_drop_down_outlined),
                          onSelected: (value) async {
                            if (mounted) {
                              setState(() {
                                selectedUser = value;
                                folder = "storage";
                              });
                            }
                            await _getFiles();
                          },
                          itemBuilder: (context) {
                            List<PopupMenuItem> menuItems = [];
                            for (User user in users) {
                              menuItems.add(
                                PopupMenuItem(
                                  value: user,
                                  child: Text(user.email ?? ""),
                                ),
                              );
                            }
                            return menuItems;
                          },
                        )
                      : Container()
                ],
              ),
            ),
          ),
          Expanded(
            child: loadingFiles
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    controller: scrollController,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (S3Folder s3folder
                              in fileListResponse?.folders ?? [])
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.folder_outlined),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  InkWell(
                                      onTap: () async {
                                        if (mounted) {
                                          setState(() {
                                            folder = s3folder.prefix
                                                    ?.split("/")
                                                    .where((part) =>
                                                        part.isNotEmpty)
                                                    .toList()
                                                    .last ??
                                                "files";
                                          });
                                        }
                                        breadCrumbs.add(folder);
                                        await _getFiles();
                                      },
                                      child: Text(
                                        s3folder.prefix
                                                ?.split("/")
                                                .where(
                                                    (part) => part.isNotEmpty)
                                                .toList()
                                                .last ??
                                            "files",
                                      )),
                                ],
                              ),
                            ),
                          for (S3ItemAttributes s3itemattribute
                              in fileListResponse?.items
                                      .where((item) => item.file != null) ??
                                  [])
                            ListTile(
                              leading: const Icon(Icons.file_open_outlined),
                              title: Text(
                                "${s3itemattribute.startDate}${s3itemattribute.endDate == null ? "" : " - ${s3itemattribute.endDate}"} ${s3itemattribute.fileDescription} ${s3itemattribute.repId}",
                              ),
                              subtitle:
                                  (s3itemattribute.file!.lastModified != null &&
                                          s3itemattribute.file!.size != null)
                                      ? Wrap(
                                          children: [
                                            Text(
                                                "Last Modified: ${DateFormat('yyyy-MM-dd: hh:mm').format(DateTime.parse(s3itemattribute.file!.lastModified ?? ""))}"),
                                            const SizedBox(
                                              width: 20,
                                            ),
                                            Text(
                                                "Size: ${formatBytes(int.tryParse(s3itemattribute.file!.size?.toString() ?? "") ?? 0, 1)}")
                                          ],
                                        )
                                      : null,
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  String? downloadFileName = s3itemattribute
                                      .file?.key
                                      ?.split("/")
                                      .last;
                                  if (downloadFileName != null) {
                                    await downloadFile(
                                        fileName: downloadFileName,
                                        otherUser: selectedUser?.id);
                                  }
                                },
                                child: const Text("Download"),
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
          )
        ],
      ),
    );
  }
}

class FileListResponse {
  List<S3ItemAttributes> items;
  List<S3Folder> folders;
  String? nextContinuationToken;

  FileListResponse({
    required this.items,
    required this.folders,
    this.nextContinuationToken,
  });

  factory FileListResponse.fromJson(Map<String, dynamic> json) {
    return FileListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  getS3ItemAttributesFromFileInfo(S3Item.fromJson(item)))
              .toList() ??
          [],
      folders: (json['folders'] as List<dynamic>?)
              ?.map((folder) => S3Folder.fromJson(folder))
              .toList() ??
          [],
      nextContinuationToken: json['nextContinuationToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items
          .where((item) {
            return item.file != null;
          })
          .map((item) => item.file?.toJson())
          .toList(),
      'folders': folders.map((folder) => folder.toJson()).toList(),
      'nextContinuationToken': nextContinuationToken,
    };
  }
}

class S3ItemAttributes {
  S3Item? file;
  String? repId;
  String? startDate;
  String? endDate;
  String? fileDescription;

  S3ItemAttributes({
    this.file,
    this.repId,
    this.startDate,
    this.endDate,
    this.fileDescription,
  });
}

class S3Item {
  String? key;
  String? lastModified;
  int? size;

  S3Item({this.key, this.lastModified, this.size});

  factory S3Item.fromJson(Map<String, dynamic> json) {
    return S3Item(
      key: json['Key'],
      lastModified: json['LastModified'],
      size: json['Size'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Key': key,
      'LastModified': lastModified,
      'Size': size,
    };
  }
}

class S3Folder {
  String? prefix;

  S3Folder({this.prefix});

  factory S3Folder.fromJson(Map<String, dynamic> json) {
    return S3Folder(
      prefix: json['Prefix'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Prefix': prefix,
    };
  }
}

Future<void> downloadFile({required String fileName, String? otherUser}) async {
  BytesBuilder bytesBuilder =
      BytesBuilder(); // Use BytesBuilder to accumulate data
  String contentType = 'application/octet-stream';
  bool responseError = false;
  Response response;
  int chunk = 0;

  do {
    chunk++;
    response = await apiGatewayGET(
      server: Uri.parse("$endpoint/file"),
      queryParameters: {
        "requestType": "file",
        "requestSource": "storage",
        "fileName": Uri.encodeComponent(fileName),
        "chunk": "$chunk",
        if (otherUser != null) "otherUser": otherUser
      },
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> body = jsonDecode(response.body);
      bytesBuilder
          .add(base64Decode(body['bytes'])); // Add decoded bytes to the builder
      contentType = body['contentType'];
    } else {
      responseError = true;
    }
  } while (responseError != true && jsonDecode(response.body)['next'] == true);

  if (!responseError) {
    Uint8List dataUint8List =
        bytesBuilder.toBytes(); // Convert accumulated bytes to Uint8List

    if (kIsWeb) {
      await WebPlugins().downloadByteData(
        dataURI: base64Encode(
            dataUint8List), // Convert to Base64 string if necessary
        contentType: contentType,
        fileName: fileName,
      );
    } else {
      String? selectedDirectory = await FilePicker.platform
          .getDirectoryPath(dialogTitle: "Choose Save Location");
      if (selectedDirectory != null) {
        await io.File("$selectedDirectory/$fileName")
            .writeAsBytes(dataUint8List);
      }
    }
  }
}

S3ItemAttributes getS3ItemAttributesFromFileInfo(S3Item input) {
  if (input.key == null) {
    return S3ItemAttributes(file: input);
  }
  Iterable<String> datesInFileName =
      input.key!.split("/").last.toString().split("_").where((item) {
    return DateTime.tryParse(item) != null;
  });

  return S3ItemAttributes(
      file: input,
      startDate: datesInFileName.isNotEmpty ? datesInFileName.first : null,
      endDate: datesInFileName.length == 2 ? datesInFileName.last : null,
      fileDescription:
          input.key!.split("/").last.toString().split("_")[0].splitCamelCase(),
      repId: input.key!.split("/").last.split("_")[1]);
}
