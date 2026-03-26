import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import './screens/login_screen.dart';
import './screens/register_step1_screen.dart';
import './screens/register_step2_screen.dart';
import './screens/forgot_password_screen.dart';
import './screens/home_screen.dart';
import './screens/city_search_screen.dart';
import './screens/comment_section_screen.dart';
import './screens/create_post_screen.dart';
import './screens/postcard_edit_screen.dart';
import './screens/map_screen.dart';
import './screens/profile_screen.dart';
import './screens/favorites_screen.dart';
import './screens/liked_posts_screen.dart';
import './screens/draft_box_screen.dart';
import './screens/postcard_overview_screen.dart';
import './screens/edit_profile_screen.dart';
import './screens/dynamic_effect_screen.dart';
import './screens/add_screen.dart';
import './screens/search_index.dart';
import './screens/search_screen.dart';
import './services/app_route_observer.dart';
import './services/auth_provider.dart';
import './services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().clearPostcardAvatarDiscussionLocalDataOnce();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider()..init(),
      child: MaterialApp(
        title: '城市明信片',
        navigatorObservers: [appRouteObserver],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const _StartupAnimationGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register1': (context) => const RegisterStep1Screen(),
          '/register2': (context) =>
              const RegisterStep2Screen(phone: '', regToken: ''),
          '/forgot_password': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/city_search': (context) => const CitySearchScreen(),
          '/comment_section': (context) => const CommentSectionScreen(),
          '/create_post': (context) => const CreatePostScreen(),
          '/postcard_edit': (context) => const PostcardEditScreen(),
          '/map': (context) => const MapScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/favorites': (context) => const FavoritesScreen(),
          '/liked_posts': (context) => const LikedPostsScreen(),
          '/draft_box': (context) => const DraftBoxScreen(),
          '/postcard_overview': (context) => const PostcardOverviewScreen(),
          '/edit_profile': (context) => const EditProfileScreen(),
          '/dynamic_effects': (context) => const DynamicEffectScreen(),
          '/add': (context) => const AddIndexPage(),
          '/search_index': (context) => const SearchIndexScreen(),
          '/search_screen': (context) => const SearchScreen(),
        },
      ),
    );
  }
}

class _StartupAnimationGate extends StatefulWidget {
  const _StartupAnimationGate();

  @override
  State<_StartupAnimationGate> createState() => _StartupAnimationGateState();
}

class _StartupAnimationGateState extends State<_StartupAnimationGate> {
  static const String _startupVideoAsset = 'assets/videos/startup.mp4';

  late final VideoPlayerController _videoController;
  Timer? _finishTimer;
  bool _videoReady = false;
  bool _showMainContent = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(_startupVideoAsset);
    _prepareAndPlayVideo();
  }

  Future<void> _prepareAndPlayVideo() async {
    try {
      await _videoController.initialize();
      if (!mounted) return;

      _videoController.setLooping(false);
      setState(() {
        _videoReady = true;
      });

      final duration = _videoController.value.duration;
      await _videoController.play();

      final safeDuration = duration > Duration.zero
          ? duration
          : const Duration(milliseconds: 1500);
      _finishTimer = Timer(
        safeDuration + const Duration(milliseconds: 150),
        _finishStartup,
      );
    } catch (_) {
      _finishStartup();
    }
  }

  void _finishStartup() {
    if (!mounted || _showMainContent) {
      return;
    }
    setState(() {
      _showMainContent = true;
    });
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showMainContent) {
      return const _AuthEntryScreen();
    }

    if (!_videoReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController.value.size.width,
            height: _videoController.value.size.height,
            child: VideoPlayer(_videoController),
          ),
        ),
      ),
    );
  }
}

class _AuthEntryScreen extends StatelessWidget {
  const _AuthEntryScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
