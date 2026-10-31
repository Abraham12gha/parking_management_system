Future<String> downloadReport(String filename, String contents) async =>
    throw UnsupportedError('Report downloads are not supported on this platform.');

Future<String> downloadReportBytes(String filename, List<int> contents) async =>
    throw UnsupportedError('PDF downloads are not supported on this platform.');
