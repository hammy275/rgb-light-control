import 'package:flutter/material.dart';
import 'package:rgb_light_control_ui/home.dart';

getApp() {
  return MaterialApp(title: "RGB Light Control",
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.red), useMaterial3: true),
      home: const Home());
}

void main() {
  runApp(getApp());
}