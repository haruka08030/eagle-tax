import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ConnectShopifyScreen extends StatefulWidget {
  const ConnectShopifyScreen({super.key});

  @override
  State<ConnectShopifyScreen> createState() => _ConnectShopifyScreenState();
}

class _ConnectShopifyScreenState extends State<ConnectShopifyScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  // IMPORTANT: This must match one of the "Allowed redirection URL(s)" in your Shopify App settings
  final String _redirectUri = 'https://your-app-url.com/callback'; 
  final String _scopes = 'read_orders'; // The permissions your app needs

  @override
  void initState() {
    super.initState();

    final shopifyApiKey = dotenv.env['SHOPIFY_API_KEY'];
    final shopName = dotenv.env['SHOPIFY_SHOP_NAME']; // In a real app, you'd ask the user for this

    if (shopifyApiKey == null || shopName == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Shopify APIキーまたはショップ名が.envファイルに設定されていません。';
      });
      return;
    }

    final authUrl =
        'https://${shopName}.myshopify.com/admin/oauth/authorize?client_id=$shopifyApiKey&scope=$_scopes&redirect_uri=$_redirectUri';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(_redirectUri)) {
              _handleRedirect(request.url);
              return NavigationDecision.prevent; // Stop the redirect
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  Future<void> _handleRedirect(String url) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '認証情報を確認しています...';
    });

    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      final shop = uri.queryParameters['shop'];

      if (code == null || shop == null) {
        throw Exception('認証に失敗しました。リダイレクトURLからコードまたはショップを取得できませんでした。');
      }

      // Invoke the Supabase Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'shopify-auth-callback',
        body: {'code': code, 'shop': shop},
      );

      if (response.status != 200) {
        throw Exception('Edge Functionの呼び出しに失敗しました: ${response.data['error']}');
      }
      
      // On success, pop the screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shopifyストアが正常に接続されました！')),
        );
        Navigator.of(context).pop(true); // Return true to signal success
      }

    } catch (e) {
      if(mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopifyと連携')),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
