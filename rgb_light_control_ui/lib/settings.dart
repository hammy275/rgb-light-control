import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

abstract class Settings {
  int transitionTimeMS = 10;
}

class RainbowSettings extends Settings {
  int stepSize = 1;
  int timeBetweenChangesMS = 10;
}

class MusicSettings extends Settings {
  List<HSVColor> colors = [];
  XFile? musicFile;
  XFile? instrumentalFile;
}