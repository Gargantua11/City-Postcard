import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import './screens/login_screen.dart';
import './screens/register_step1_screen.dart';
import './screens/register_step2_screen.dart';
import './screens/forgot_password_screen.dart';
import './screens/home_screen.dart';
import './screens/city_search_screen.dart';
import './screens/comment_section_screen.dart';
import './screens/postcard_edit_screen.dart';
import './screens/map_screen.dart';
import './screens/profile_screen.dart';
import './screens/add_screen.dart';
import './screens/search_index.dart';
import './screens/search_screen.dart';
import './services/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        initialRoute: '/map',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register1': (context) => const RegisterStep1Screen(),
          '/register2': (context) => const RegisterStep2Screen(phone: ''),
          '/forgot_password': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/city_search': (context) => const CitySearchScreen(),
          '/comment_section': (context) => const CommentSectionScreen(),
          '/postcard_edit': (context) => const PostcardEditScreen(),
          '/map': (context) => const MapScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/add': (context) => const AddIndexPage(),
          '/search_index': (context) => const SearchIndexScreen(),
          '/search_screen': (context) => const SearchScreen(),
        },
      ),
    );
  }
}
