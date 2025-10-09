import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// صفحة لاختبار معلومات الجهاز
/// يمكن استخدامها للتحقق من صحة البيانات
class TestDeviceInfoScreen extends StatefulWidget {
  const TestDeviceInfoScreen({super.key});

  @override
  State<TestDeviceInfoScreen> createState() => _TestDeviceInfoScreenState();
}

class _TestDeviceInfoScreenState extends State<TestDeviceInfoScreen> {
  String deviceInfo = 'Loading...';

  @override
  void initState() {
    super.initState();
    _getDeviceInfo();
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String info = '';

    try {
      if (kIsWeb) {
        // Web
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        info = '''
🌐 Web Platform
Browser: ${webInfo.browserName}
Platform: ${webInfo.platform}
User Agent: ${webInfo.userAgent}
''';
      } else if (Platform.isAndroid) {
        // Android
        final androidInfo = await deviceInfoPlugin.androidInfo;
        info = '''
🤖 Android Platform
Manufacturer: ${androidInfo.manufacturer}
Brand: ${androidInfo.brand}
Model: ${androidInfo.model}
Device: ${androidInfo.device}
Product: ${androidInfo.product}
Android Version: ${androidInfo.version.release}
SDK Int: ${androidInfo.version.sdkInt}
Is Physical Device: ${androidInfo.isPhysicalDevice}
''';
      } else if (Platform.isIOS) {
        // iOS
        final iosInfo = await deviceInfoPlugin.iosInfo;
        info = '''
🍎 iOS Platform
Name: ${iosInfo.name}
Model: ${iosInfo.model}
System Name: ${iosInfo.systemName}
System Version: ${iosInfo.systemVersion}
Is Physical Device: ${iosInfo.isPhysicalDevice}
''';
      } else {
        info = 'Platform: ${Platform.operatingSystem}';
      }
    } catch (e) {
      info = 'Error: $e';
    }

    setState(() {
      deviceInfo = info;
    });

    // طباعة في console أيضاً
    print('═══════════════════════════════════════════════════════════');
    print('📱 Device Information:');
    print('═══════════════════════════════════════════════════════════');
    print(info);
    print('═══════════════════════════════════════════════════════════');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Info Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Information:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                deviceInfo,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getDeviceInfo,
              child: const Text('Refresh Info'),
            ),
          ],
        ),
      ),
    );
  }
}
