import 'package:flutter/material.dart';

import 'core/webrtc/webrtc_service.dart';
import 'features/file_transfer/presentation/bloc/file_bloc.dart';
import 'features/file_transfer/presentation/pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(FileBloc(WebRTCService.instance)),
    );
  }
}
