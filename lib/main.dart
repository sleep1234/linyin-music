import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/music_source_service.dart';
import 'services/player_service.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 存储服务（最先初始化，其他服务依赖它）
        Provider(create: (_) => StorageService()),
        // 音乐源服务
        ChangeNotifierProxyProvider<StorageService, MusicSourceService>(
          create: (ctx) => MusicSourceService(ctx.read<StorageService>()),
          update: (_, storage, service) => service ?? MusicSourceService(storage),
        ),
        // 播放器服务
        ChangeNotifierProxyProvider2<StorageService, MusicSourceService, PlayerService>(
          create: (ctx) => PlayerService(
            ctx.read<MusicSourceService>(),
            ctx.read<StorageService>(),
          ),
          update: (_, storage, source, player) =>
              player ?? PlayerService(source, storage),
        ),
      ],
      child: MaterialApp(
        title: '森林之音',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFEC4141),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFEC4141),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
