import 'dart:convert';
import 'dart:html' as html;

Future<String> downloadReport(String filename, String contents) async {
  final url = Uri.dataFromString(contents, mimeType: 'text/csv', encoding: utf8).toString();
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  return filename;
}

Future<String> downloadReportBytes(String filename, List<int> contents) async {
  final blob = html.Blob([contents], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
