import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class ApiConfig {
  static String getBaseUrl() {
    // Allow temporary override without changing defaults or committing secrets.
    const envOverride = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (envOverride.isNotEmpty) {
      return envOverride.endsWith('/community')
          ? envOverride
          : '${envOverride.replaceAll(RegExp(r'\/$'), '')}/community';
    }

    // 1. WEB LOGIC (Codespaces & Forwarded Ports)
    if (kIsWeb) {
      try {
        // MAGIC FIX: Uri.base gets the web URL safely without dart:html!
        final uri = Uri.base;

        // Check if we're in GitHub Codespaces
        if (uri.host.contains('app.github.dev')) {
          final hostParts = uri.host.split('-');
          if (hostParts.length >= 2) {
            final codespacePrefix =
                hostParts.sublist(0, hostParts.length - 1).join('-');
            final backendUrl = 'https://$codespacePrefix-8000.app.github.dev';

            debugPrint('🌐 Detected Codespaces environment');
            debugPrint('🔗 Using backend URL: $backendUrl/community');
            return '$backendUrl/community';
          }
        }

        // ✅ PRODUCTION FIX: Check for Firebase Hosting domains
        // Use same-origin relative URL - firebase.json rewrites /community/** → Cloud Function
        // This avoids CORS entirely as it's a same-origin request.
        if (uri.host.contains('web.app') ||
            uri.host.contains('firebaseapp.com')) {
          final origin = '${uri.scheme}://${uri.host}';
          debugPrint('🚀 Detected Firebase production environment');
          debugPrint('🔗 Using same-origin community URL: $origin/community');
          return '$origin/community';
        }

        // Check if we're running on a forwarded port (but exclude localhost/127.0.0.1)
        if (uri.port != 0 && uri.port != 80 && uri.port != 443) {
          if (uri.host != 'localhost' && uri.host != '127.0.0.1') {
            final backendUrl =
                '${uri.scheme}://${uri.host.split('-').first}-8000.${uri.host.split('-').sublist(1).join('-')}';
            debugPrint('🔗 Using forwarded port URL: $backendUrl/community');
            return '$backendUrl/community';
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error detecting environment: $e');
      }
    }

    // 2. MOBILE LOGIC (Physical Device & Emulator)
    if (!kIsWeb) {
      // Default for mobile / emulator: use localhost / emulator mapping.
      const String physicalDeviceIp = '127.0.0.1';
      // Note: For Android emulator you may need to use 10.0.2.2 instead.
      debugPrint(
          '📱 Using Physical Device/Emulator backend: http://$physicalDeviceIp:8000/community');
      return 'http://$physicalDeviceIp:8000/community';
    }

    // 3. DEFAULT FALLBACK
    debugPrint('🏠 Using localhost backend: http://localhost:8000/community');
    return 'http://localhost:8000/community';
  }
}
