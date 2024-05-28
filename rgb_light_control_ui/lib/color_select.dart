import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorSelect extends StatelessWidget {

  final int index;
  final HSVColor color;
  final void Function(int, HSVColor) setColor;
  final ValueChanged<int> doRemove;

  const ColorSelect({super.key, required this.index, required this.color, required this.setColor,
    required this.doRemove});

  @override
  Widget build(BuildContext context) {
    // Thanks to https://stackoverflow.com/questions/66450873/how-to-create-circle-container-with-border-in-flutter
    return Column(children: [
      TextButton(
          onPressed: () => showModalBottomSheet(context: context, builder: (BuildContext context) {
            return ColorPicker(pickerColor: color.toColor(),
              onColorChanged: (color) => setColor(index, HSVColor.fromColor(color)), portraitOnly: true,
            );
          }),
          child: Container(width: 32, height: 32,
              decoration: BoxDecoration(color: Theme.of(context).textTheme.titleLarge?.color, shape: BoxShape.circle),
              child: Padding(padding: const EdgeInsets.all(3),
                  child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color.toColor())
                  )))
      ),
      IconButton(onPressed: () => doRemove(index), icon: const Icon(Icons.delete_outline))
    ]);

  }

}