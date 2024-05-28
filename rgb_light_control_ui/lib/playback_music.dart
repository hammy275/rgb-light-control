import 'dart:convert';
import 'dart:js_interop';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:rgb_light_control_ui/settings.dart';

import 'constants.dart';

class MusicPlayback extends StatefulWidget {

  final List<String> lightNames;
  final String modeName;
  final MusicSettings settings;

  const MusicPlayback({super.key, required this.lightNames, required this.modeName, required this.settings});

  @override
  State<StatefulWidget> createState() {
    return MusicPlaybackState();
  }

  String getModeFromName() {
    if (modeName == "Cycle to Music") {
      return "cycle";
    } else {
      return "gradient";
    }
  }

}

class MusicPlaybackState extends State<MusicPlayback> {

  late Future<Map?> futureSendDelay;
  late Future<void> musicPlaying;
  int hValue = 0;

  Future<Map> getLightData() async {
    // Get instrumental to send
    XFile? instrumental = widget.settings.instrumentalFile ?? widget.settings.musicFile;
    if (instrumental == null) {
      throw Exception("No music chosen!");
    }

    // Get light delay
    final stopwatch = Stopwatch();
    stopwatch.start();
    final _ = await http.post(Uri.parse("${Constants.apiRoot}/ping"));
    stopwatch.stop();
    final lightDelayResp = await http.post(Uri.parse("${Constants.apiRoot}/estimate_light_delay"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"lights": widget.lightNames})
    );
    final double approximateRequestTime = stopwatch.elapsed.inMilliseconds / 1000 / 2;
    if (lightDelayResp.statusCode == 200) {
      final lightDelayFromServer = jsonDecode(lightDelayResp.body)["data"];
      double sendDelay = lightDelayFromServer + approximateRequestTime;

      // Calculate light change timings
      final colorList = [];
      for (final color in widget.settings.colors) {
        colorList.add({"h": color.hue.round(), "s": (color.saturation * 100).round(), "v": (color.value * 100).round()});
      }
      final musicCalcResp = await http.post(Uri.parse("${Constants.apiRoot}/calculate_music_timings"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"mode": widget.getModeFromName(), "send_delay": sendDelay, "colors": colorList,
            "file": {"filename": "file", "data": const Base64Encoder().convert(await instrumental.readAsBytes())}}));
      return jsonDecode(musicCalcResp.body);
    } else {
      throw Exception("Failed to get light send delay ${lightDelayResp.body}");
    }
  }

  Future<void> playMusic() async {
    await futureSendDelay;
    final player = AudioPlayer();
    // TODO: Play audio
}

  @override
  void initState() {
    super.initState();
    futureSendDelay = getLightData();
    musicPlaying = playMusic();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(future: futureSendDelay, builder: (context, snapshot) {
      if (snapshot.hasData) {
        return FutureBuilder(future: musicPlaying, builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Music done playing
            Navigator.pop(context);
          } else if (snapshot.hasError) {
            return Text("${snapshot.error}");
          } else {
            // TODO: "Playing audio" widget state
          }
        });
      } else if (snapshot.hasError) {
        return Text("${snapshot.error}");
      } else {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32, horizontal: 128),
          child: Wrap(
            direction: Axis.vertical,
            spacing: 32,
            alignment: WrapAlignment.spaceEvenly,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text("Loading Music Data..."),
              CircularProgressIndicator(value: null)
            ],
          ),
        );
      }
    });
  }
}