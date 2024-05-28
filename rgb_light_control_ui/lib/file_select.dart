import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class FileSelect extends StatelessWidget {

  final String label;
  final XFile? fileChosen;
  final ValueSetter<XFile?> fileSetter;
  final List<XTypeGroup> fileTypes;

  const FileSelect({super.key, required this.label, required this.fileChosen,
    required this.fileSetter, required this.fileTypes});

  Future<void> selectFile() async {
    XFile? file = await openFile(acceptedTypeGroups: fileTypes);
    bool matches = false;
    if (file != null) {
      for (final fileType in fileTypes) {
        List<String>? extensions = fileType.extensions;
        if (extensions != null) {
          for (final extension in extensions) {
            if (file.name.endsWith(extension)) {
              matches = true;
              break;
            }
          }
        }
        if (matches) {
          break;
        }
      }
    }
    if (matches) {
      fileSetter(file);
    } else {
      fileSetter(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Padding(padding: const EdgeInsets.all(16), child: Text(label)),
      Padding(padding: const EdgeInsets.all(16), child: FilledButton(onPressed: () => selectFile(), child: const Text("Select File"))),
      Padding(padding: const EdgeInsets.all(16), child: Text(fileChosen != null ? fileChosen!.name : "No file chosen"))
    ]);
  }

}