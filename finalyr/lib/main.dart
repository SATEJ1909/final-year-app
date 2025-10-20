import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/socket_io_service.dart'; // adjust path as needed
import 'presentation/screens/home_screen.dart'; // or your entry screen

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SocketService(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambulance Tracking System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const HomeScreen(), // Start from your HomeScreen
    );
  }
}