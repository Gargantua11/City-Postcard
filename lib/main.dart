import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import './screens/login_screen.dart';
import './screens/register_step1_screen.dart';
import './screens/register_step2_screen.dart';
import './screens/forgot_password_screen.dart';
import './screens/home_screen.dart';
import './screens/city_search_screen.dart';
import './screens/discussion_under_development_screen.dart';
import './screens/create_post_screen.dart';
import './screens/postcard_edit_screen.dart';
import './screens/map_screen.dart';
import './screens/profile_screen.dart';
import './screens/favorites_screen.dart';
import './screens/draft_box_screen.dart';
import './screens/postcard_overview_screen.dart';
import './screens/edit_profile_screen.dart';
import './screens/dynamic_effect_screen.dart';
import './screens/add_screen.dart';
import './screens/search_index.dart';
import './screens/search_screen.dart';
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register1': (context) => const RegisterStep1Screen(),
          '/register2': (context) =>
              const RegisterStep2Screen(phone: '', regToken: ''),
          '/forgot_password': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/city_search': (context) => const CitySearchScreen(),
          '/comment_section': (context) =>
              const DiscussionUnderDevelopmentScreen(),
          '/create_post': (context) => const CreatePostScreen(),
          '/postcard_edit': (context) => const PostcardEditScreen(),
          '/map': (context) => const MapScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/favorites': (context) => const FavoritesScreen(),
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
