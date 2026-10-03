import 'dart:io';

Future<String> downloadReport(String filename, String contents) async {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  final downloads = home == null ? null : Directory('$home${Platform.pathSeparator}Downloads');
  final directory = downloads != null && await downloads.exists()
      ? downloads
      : Directory.systemTemp;
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await file.writeAsString(contents, flush: true);
  return file.path;
}
