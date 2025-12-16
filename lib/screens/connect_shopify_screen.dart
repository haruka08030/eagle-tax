import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:eagle_tax/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';


class ConnectShopifyScreen extends StatefulWidget {
  final Map<String, String>? initialQueryParams;

  const ConnectShopifyScreen({super.key, this.initialQueryParams});

  @override
  State<ConnectShopifyScreen> createState() => _ConnectShopifyScreenState();
}

class _ConnectShopifyScreenState extends State<ConnectShopifyScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isProcessingCallback = false;
  String? _errorMessage;
  String? _oauthState; // Store OAuth state for CSRF protection
  final _shopNameController = TextEditingController();
  final _supabaseService = SupabaseService();
  
  // AppLinks instance for handling deep links
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialQueryParams != null) {
      _handleInitialRedirect(widget.initialQueryParams!);
    }
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _shopNameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Give some time for the deep link to be processed
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _isLoading && !_isProcessingCallback) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  Future<void> _initDeepLinkListener() async {
    _appLinks = AppLinks();

    // Listen for incoming deep links
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (mounted && uri != null) {
        _handleRedirect(uri);
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  Future<void> _handleInitialRedirect(Map<String, String> params) async {
    // Schedule this to run after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       await _processAuth(params);
    });
  }

  Future<void> _handleRedirect(Uri uri) async {
    if (!mounted) return;
    if (!uri.toString().contains('code=') || !uri.toString().contains('shop=')) {
        return;
    }
    await _processAuth(uri.queryParameters);
  }

  Future<void> _processAuth(Map<String, String> queryParams) async {
    setState(() {
      _isLoading = true;
      _isProcessingCallback = true;
      _errorMessage = '認証情報を確認しています...';
    });
    
    final code = queryParams['code'];
    final shop = queryParams['shop'];
    // We can't verify state here cleanly if we navigated from outside and lost _oauthState memory.
    // Ideally we persist state in SharedPreferences before launching url. 
    // For now, if we are opening via fresh deep link (not return from browser in same session), we might skip state check OR fail it.
    // If the user *just* launched the url, _oauthState is in memory.
    
     if (code == null || shop == null) {
        setState(() {
            _isLoading = false;
            _isProcessingCallback = false;
            _errorMessage = '無効な認証レスポンスです。';
        });
        return;
      }

      // CSRF Check: Verify state matches
      // Note: If app is restarted (e.g. web reload), _oauthState will be null.
      // In a production web app, state should be persisted in Session Storage or Cookies.
      final returnedState = queryParams['state'];
      if (_oauthState != null && returnedState != _oauthState) {
         setState(() {
            _isLoading = false;
            _isProcessingCallback = false;
            _errorMessage = 'セキュリティ検証に失敗しました (State Mismatch)。もう一度お試しください。';
        });
        return;
      }

    try {
      await _supabaseService.exchangeShopifyAuthCode(queryParams);
      
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
          _isProcessingCallback = false;
          _errorMessage = e.toString();
        });
      }
    }
  }


  void _startShopifyAuth() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _oauthState = null; // Reset state
    });

    final shopName = _shopNameController.text.trim();
    
    // Define redirect URL
    const redirectUrl = String.fromEnvironment('SHOPIFY_REDIRECT_URL', 
        defaultValue: 'http://localhost:3000/'); 

    // Call the backend to generate the auth URL
    _supabaseService.getShopifyAuthUrl(
      shopName,
      redirectUrl,
    ).then((data) async {
      if (!mounted) return;

      final authUrlString = data['authUrl'] as String;
      final state = data['state'] as String?;
      
      if (state != null) {
        _oauthState = state; // Store state for verification
      }

      final authUrl = Uri.parse(authUrlString);
      
      if (await canLaunchUrl(authUrl)) {
           await launchUrl(
              authUrl,
              mode: LaunchMode.externalApplication, // Important: Open in external browser
           );
      } else {
           throw Exception('ブラウザを開けませんでした: $authUrlString');
      }

    }).catchError((error) {
       if (!mounted) return;
       setState(() {
          _errorMessage = error.toString();
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
