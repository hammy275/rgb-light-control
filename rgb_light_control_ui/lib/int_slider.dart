import 'package:flutter/material.dart';

class IntSlider extends StatelessWidget {

  final int value;
  final String leftLabel;
  final String rightLabel;
  final int min;
  final int max;
  final ValueSetter<int> valueSetter;

  const IntSlider({super.key, required this.value, required this.min, required this.max,
    required this.leftLabel, required this.rightLabel, required this.valueSetter});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 3, child: Text(leftLabel)),
      Expanded(flex: 5, child: Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          onChanged: (double newValue) {
            valueSetter(newValue.round());
          }
      )),
      Expanded(flex: 1, child: Text(rightLabel))
    ]);
  }

}