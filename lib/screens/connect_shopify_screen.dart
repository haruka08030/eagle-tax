import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:eagle_tax/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';


class ConnectShopifyScreen extends StatefulWidget {
  const ConnectShopifyScreen({super.key});

  @override
  State<ConnectShopifyScreen> createState() => _ConnectShopifyScreenState();
}

class _ConnectShopifyScreenState extends State<ConnectShopifyScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
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
        if (mounted && _isLoading && _errorMessage == null) {
          // If still loading but no status message set (meaning _handleRedirect hasn't updated it),
          // assume user cancelled or returned without auth.
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

  Future<void> _handleRedirect(Uri uri) async {
    if (!mounted) return;
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
    final returnedState = uri.queryParameters['state'];
    
     if (code == null || shop == null) {
        setState(() {
            _isLoading = false;
            _errorMessage = '無効な認証レスポンスです。';
        });
        return;
      }
      
      // CSRF Check: Verify state matches
      if (_oauthState == null || returnedState != _oauthState) {
         setState(() {
            _isLoading = false;
            _errorMessage = 'セキュリティ検証に失敗しました (State Mismatch)。もう一度お試しください。';
        });
        return;
      }

    try {
      await _supabaseService.exchangeShopifyAuthCode(uri.queryParameters);
      
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
      _oauthState = null; // Reset state
    });

    final shopName = _shopNameController.text.trim();
    
    // Call the backend to generate the auth URL
    _supabaseService.getShopifyAuthUrl(
      shopName,
      'http://localhost:3000/',
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
           // We remain in loading state waiting for the callback...
           // OR we can stop loading and let the user wait. 
           // Ideally show "Waiting for completion..."
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
