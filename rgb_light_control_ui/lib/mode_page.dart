
import 'package:flutter/material.dart';
import 'package:rgb_light_control_ui/int_slider.dart';
import 'package:rgb_light_control_ui/settings.dart';

class ModePage extends StatefulWidget {
  final String selectedMode;
  final ValueSetter<String> setMode;
  final RainbowSettings rainbowSettings;

  const ModePage({super.key, required this.selectedMode, required this.setMode, required this.rainbowSettings});

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
    Widget settingsWidget = widget.selectedMode == "Rainbow" ? rainbowSettingsWidget(context) : const Text("Settings unimplemented");
    return Column(
      children: [
        Column(children: options),
        const Padding(padding: EdgeInsets.all(20),child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: settingsWidget)
      ]
    );
  }

  Widget rainbowSettingsWidget(BuildContext context) {
    return Column(
      children: [
        IntSlider(value: widget.rainbowSettings.transitionTimeMS, min: 0, max: 1000,
            leftLabel: "Transition Time (the time spent fading between colors)",
            rightLabel: "${widget.rainbowSettings.transitionTimeMS} ms",
            valueSetter: (int newValue) {
              setState(() {
                widget.rainbowSettings.transitionTimeMS = newValue;
              });
            }),
        IntSlider(value: widget.rainbowSettings.stepSize, min: 1, max: 9,
            leftLabel: "Step Size (the amount of color, out of 360, to go forward)",
            rightLabel: "${widget.rainbowSettings.stepSize}",
            valueSetter: (int newValue) {
              setState(() {
                widget.rainbowSettings.stepSize = newValue;
              });
            }),
        IntSlider(value: widget.rainbowSettings.timeBetweenChangesMS, min: 0, max: 1000,
            leftLabel: "Wait Time (the time spent waiting between color changes)",
            rightLabel: "${widget.rainbowSettings.timeBetweenChangesMS} ms",
            valueSetter: (int newValue) {
              setState(() {
                widget.rainbowSettings.timeBetweenChangesMS = newValue;
              });
            }),
      ],
    );
  }
}