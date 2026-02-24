import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window;

class ApiConfig {
  static String getBaseUrl() {
    // Check if running on web
    if (kIsWeb) {
      try {
        // Get current hostname
        final currentUrl = html.window.location.href;
        final uri = Uri.parse(currentUrl);
        
        // Check if we're in GitHub Codespaces
        if (uri.host.contains('app.github.dev')) {
          // Extract codespace name from the URL
          // Format: https://CODESPACE_NAME-PORT.app.github.dev
          final hostParts = uri.host.split('-');
          if (hostParts.length >= 2) {
            // Remove the port suffix from the last part
            final lastPart = hostParts.last.split('.').first;
            
            // Reconstruct with backend port (8000)
            final codespacePrefix = hostParts.sublist(0, hostParts.length - 1).join('-');
            final backendUrl = 'https://$codespacePrefix-8000.app.github.dev';
            
            print('🌐 Detected Codespaces environment');
            print('🔗 Using backend URL: $backendUrl/community');
            return '$backendUrl/community';
          }
        }
        
        // Check if we're running on a forwarded port
        if (uri.port != 0 && uri.port != 80 && uri.port != 443) {
          // Use the same host but with port 8000
          final backendUrl = '${uri.scheme}://${uri.host.split('-').first}-8000.${uri.host.split('-').sublist(1).join('-')}';
          print('🔗 Using forwarded port URL: $backendUrl/community');
          return '$backendUrl/community';
        }
      } catch (e) {
        print('⚠️ Error detecting environment: $e');
      }
    }
    
    // Default to localhost for development
    print('🏠 Using localhost backend: http://localhost:8000/community');
    return 'http://localhost:8000/community';
  }
}
