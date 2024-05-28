import 'dart:convert';
import 'dart:js_interop';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:rgb_light_control_ui/settings.dart';
import 'package:rgb_light_control_ui/xfile_audio_source.dart';

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

  late Future<Map?> lightDataFuture;
  late Future<AudioPlayer> musicPlayer;
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
      return jsonDecode(musicCalcResp.body)["data"];
    } else {
      throw Exception("Failed to get light send delay ${lightDelayResp.body}");
    }
  }

  Future<AudioPlayer> loadMusic() async {
    if (widget.settings.musicFile != null) {
      final player = AudioPlayer();
      await player.setAudioSource(XFileAudioSource(widget.settings.musicFile!));
      return player;
    } else {
      throw Exception("No music chosen!");
    }
  }

  Future<void> playMusic() async {
    Map? lightData = await lightDataFuture;
    AudioPlayer player = await musicPlayer;
    if (lightData != null) {
      List<double> times = List<double>.from(lightData["times"] as List);
      List<Map> colors = List<Map>.from(lightData["colors"] as List);
      int index = 0;
      Future<void> playback = player.play();
      while (index < times.length) {
        final nextTime = times[index];
        final nextColor = jsonEncode(colors[index]);
        double playbackTime;
        do {
          playbackTime = player.position.inMilliseconds / 1000;
        } while (playbackTime < nextTime);
        await http.post(Uri.parse("${Constants.apiRoot}/set_hsv"),
            headers: {"Content-Type": "application/json"},
            body: nextColor
        );
        index += 1;
      }
      await playback;
    }
  }

  @override
  void initState() {
    super.initState();
    lightDataFuture = getLightData();
    musicPlayer = loadMusic();
    musicPlaying = playMusic();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(future: Future.wait([lightDataFuture, musicPlayer]), builder: (context, snapshot) {
      if (snapshot.hasData) {
        return FutureBuilder(future: musicPlaying, builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Music done playing
            Navigator.pop(context);
            return const Text("Music ended!");
          } else if (snapshot.hasError) {
            return Text("${snapshot.error}");
          } else {
            // TODO: "Playing audio" widget state
            return const Text("Playing back music (better UI unimplemented)...");
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