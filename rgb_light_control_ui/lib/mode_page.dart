
import 'package:flutter/material.dart';

class ModePage extends StatefulWidget {
  final String selectedMode;
  final ValueSetter<String> setMode;

  const ModePage({super.key, required this.selectedMode, required this.setMode});

  @override
  State<StatefulWidget> createState() {
    return ModePageState();
  }
}

class ModePageState extends State<ModePage> {
  static const modes = ["Rainbow", "Cycle to Music", "Fade with Music"];

  @override
  Widget build(BuildContext context) {
    List<RadioListTile<String>> options = [];
    for (final mode in modes) {
      options.add(RadioListTile(value: mode, groupValue: widget.selectedMode, title: Text(mode), onChanged: (String? value) {
        widget.setMode(value!);
      }));
    }
    return Column(
      children: options
    );
  }
}