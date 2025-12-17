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
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  WebViewController? _controller;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showWebView = false;

  final String _redirectUri = dotenv.env['SHOPIFY_REDIRECT_URI'] ?? '';

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _getShopifyAuthUrlAndLoadWebView() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shopName = _shopNameController.text.trim();
      final response = await Supabase.instance.client.functions.invoke(
        'get-shopify-auth-url',
        body: {'shop_name': shopName},
      );

      if (response.status != 200) {
        throw Exception('認証URLの取得に失敗しました: ${response.data}');
      }

      final authUrl = response.data['authUrl'];

      final controller = WebViewController()
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
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(authUrl));

      setState(() {
        _controller = controller;
        _showWebView = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRedirect(String url) async {
    String? _statusMessage;
    setState(() {
      _isLoading = true;
      _statusMessage = '認証情報を確認しています...';
    });

    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      final shop = uri.queryParameters['shop'];

      if (code == null || shop == null) {
        throw Exception('認証に失敗しました。リダイレクトURLからコードまたはショップを取得できませんでした。');
      }

      final response = await Supabase.instance.client.functions.invoke(
        'shopify-auth-callback',
        body: {'code': code, 'shop': shop},
      );

      if (response.status < 200 || response.status >= 300) {
        final errorMsg = response.data is Map ? response.data['error'] ?? 'Unknown error' : 'Unknown error';
        throw Exception('Edge Functionの呼び出しに失敗しました: $errorMsg');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shopifyストアが正常に接続されました！')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isLoading = false;
                    _showWebView = false;
                    _shopNameController.clear();
                  });
                },
                child: const Text('やり直す'),
              )
            ],
          ),
        ),
      );
    }

    if (_showWebView && _controller != null) {
      return Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Shopifyストアのドメイン名を入力してください',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '例: "your-store.myshopify.com" の場合は "your-store" と入力',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _shopNameController,
              decoration: const InputDecoration(
                labelText: 'ストア名',
                border: OutlineInputBorder(),
                suffixText: '.myshopify.com',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'ストア名を入力してください';
                }
                if (value.contains('.')) {
                  return '".myshopify.com" より前の部分のみ入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _getShopifyAuthUrlAndLoadWebView,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('連携する'),
            ),
          ],
        ),
      ),
    );
  }
}
