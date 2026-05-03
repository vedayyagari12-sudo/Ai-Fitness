import 'package:flutter/material.dart';
import 'api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Fitness',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String status = 'Checking connection...';

  @override
  void initState() {
    super.initState();
    checkBackend();
  }

  void checkBackend() async {
    final connected = await testConnection();
    setState(() {
      status = connected
          ? '✅ Backend connected!'
          : '❌ Could not reach backend';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Fitness')),
      body: Center(
        child: Text(
          status,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
// 