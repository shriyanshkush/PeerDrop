import 'package:flutter/material.dart';
import 'core/webrtc/webrtc_service.dart';
import 'features/file_transfer/presentation/bloc/file_bloc.dart';
import 'features/file_transfer/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //await WebRTCService.instance.init();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(FileBloc(WebRTCService.instance)),
    );
  }
}