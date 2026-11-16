import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive storage for IndexedDB on Web
  await Hive.initFlutter();
  await Hive.openBox('chat_history');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: const LocalAIAgentApp(),
    ),
  );
}

class LocalAIAgentApp extends StatelessWidget {
  const LocalAIAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local AI Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}