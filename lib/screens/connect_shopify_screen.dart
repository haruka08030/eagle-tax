import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';


class ConnectShopifyScreen extends StatefulWidget {
  const ConnectShopifyScreen({super.key});

  @override
  State<ConnectShopifyScreen> createState() => _ConnectShopifyScreenState();
}

class _ConnectShopifyScreenState extends State<ConnectShopifyScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  final _shopNameController = TextEditingController();
  
  // AppLinks instance for handling deep links
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _initDeepLinkListener() async {
    _appLinks = AppLinks();

    // Listen for incoming deep links
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleRedirect(uri);
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  Future<void> _handleRedirect(Uri uri) async {
    // Check if this is the Shopify callback
    // The path should match your configured redirect URI path, e.g., /shopify-callback
    // Or you can check specific query params.
    if (!uri.toString().contains('code=') || !uri.toString().contains('shop=')) {
        return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '認証情報を確認しています...';
    });
    
    // Validate state if implemented, etc.
    final code = uri.queryParameters['code'];
    final shop = uri.queryParameters['shop'];
    
     if (code == null || shop == null) {
        setState(() {
            _isLoading = false;
            _errorMessage = '無効な認証レスポンスです。';
        });
        return;
      }


    try {
      final response = await Supabase.instance.client.functions.invoke(
        'shopify-auth-callback',
        body: {'code': code, 'shop': shop},
      );

      if (response.status < 200 || response.status >= 300) {
        final errorMsg = response.data is Map ? response.data['error'] ?? 'Unknown error' : 'Unknown error';
        throw Exception('Edge Functionの呼び出しに失敗しました: $errorMsg');
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


  void _startShopifyAuth() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final shopName = _shopNameController.text.trim();
    
    // Call the backend to generate the auth URL
    Supabase.instance.client.functions.invoke(
      'get-shopify-auth-url',
      body: {
        'shopName': shopName,
        'redirectUri': 'http://localhost:3000/',
      },
    ).then((response) async {
      if (!mounted) return;

      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;
        final authUrlString = data['authUrl'] as String;
        // redirectUri is returned but we don't strictly need it here if the backend configured it correctly for the OAuth URL.
        // But we DO need to make sure the app is listening for it.

        final authUrl = Uri.parse(authUrlString);
        
        if (await canLaunchUrl(authUrl)) {
             await launchUrl(
                authUrl,
                mode: LaunchMode.externalApplication, // Important: Open in external browser
             );
             // We remain in loading state waiting for the callback...
             // OR we can stop loading and let the user wait. 
             // Ideally show "Waiting for completion..."
        } else {
             throw Exception('ブラウザを開けませんでした: $authUrlString');
        }

      } else {
        final errorMsg = response.data is Map 
            ? response.data['error'] ?? 'Server error' 
            : 'Server error: ${response.status}';
        
        throw Exception(errorMsg);
      }
    }).catchError((error) {
       if (!mounted) return;
       setState(() {
          _errorMessage = 'エラー: $error';
          _isLoading = false;
       });
    });
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopifyと連携'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'あなたのShopifyストアに接続します。\n\n「Shopifyに接続」およびボタンを押すと、ブラウザが開きます。ログインと承認を行ってください。',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _shopNameController,
            decoration: const InputDecoration(
              labelText: 'ショップ名',
              hintText: 'your-store-name',
              helperText: 'ストアURLの ".myshopify.com" の前の部分です。',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            autocorrect: false,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _startShopifyAuth,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Shopifyに接続'),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
             Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade50,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
             ),
        ],
      ),
    );
  }
}
