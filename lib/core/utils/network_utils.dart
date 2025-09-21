import 'dart:io';

/// Checks for real internet access by looking up a reliable host.
Future<bool> hasRealInternet() async {
  try {
    // Using Google's public DNS server as a reliable target for lookup.
    final result = await InternetAddress.lookup('8.8.8.8');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}
