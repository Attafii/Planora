// Browser-only delivery; the account snapshot never enters a public URL.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool downloadAccountExport(String content) {
  final blob = html.Blob([content], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = 'planify-account.json';
  anchor.click();
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => html.Url.revokeObjectUrl(url),
  );
  return true;
}
