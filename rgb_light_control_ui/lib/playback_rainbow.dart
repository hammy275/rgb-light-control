import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';

class RainbowPlayback extends StatefulWidget {

  final List<String> lightNames;

  const RainbowPlayback({super.key, required this.lightNames});

  @override
  State<StatefulWidget> createState() {
    return RainbowPlaybackState();
  }
}

class RainbowPlaybackState extends State<RainbowPlayback> {

  int hValue = 0;
  bool canceled = false;

  Future<void> runRainbow() async {
    while (true) {
      await http.post(Uri.parse("${Constants.apiRoot}/set_hsv"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"h": hValue, "s": 100, "v": 100, "transition": 10, "lights": widget.lightNames})
      );
      if (++hValue > 360) {
        hValue = 0;
      }
      if (canceled) {
        break;  // Placed here to minimize the odds we call setState() after cancelling
      }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  void initState() {
    super.initState();
    runRainbow();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 128),
      child: Wrap(
        direction: Axis.vertical,
        spacing: 32,
        alignment: WrapAlignment.spaceEvenly,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text("Running Rainbow Lights!"),
          CircularProgressIndicator(value: null,
              valueColor: AlwaysStoppedAnimation(HSVColor.fromAHSV(1, hValue as double, 1, 1).toColor())
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    canceled = true;
  }
}