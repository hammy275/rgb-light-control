import 'dart:convert';

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
  bool canceled = false;
  Color playbackColor = Colors.black;

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
      List<double> timesMS = List<double>.from(lightData["times"] as List);
      for (int i = 0; i < timesMS.length; i++) {
        timesMS[i] *= 1000;
      }
      List<Map> colorsJSON = List<Map>.from(lightData["colors"] as List);
      List<Color> colorsColors = [];
      for (final color in colorsJSON) {
        colorsColors.add(HSVColor.fromAHSV(1, color["h"].round(), (color["s"] / 100).round(), (color["v"] / 100).round()).toColor());
      }
      int index = 0;
      Future<void> playback = player.play();
      while (index < timesMS.length && !canceled) {
        final nextTime = timesMS[index];
        final nextColorJSON = jsonEncode(colorsJSON[index]);
        final nextColorColor = colorsColors[index];
        double waitTime = nextTime - player.position.inMilliseconds;
        Future.delayed(Duration(milliseconds: waitTime.floor()));
        setState(() {
          playbackColor = nextColorColor;
        });
        await http.post(Uri.parse("${Constants.apiRoot}/set_hsv"),
            headers: {"Content-Type": "application/json"},
            body: nextColorJSON
        );
        index += 1;
      }
      if (canceled) {
        player.stop();
      } else {
        await playback;
      }
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
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 128),
              child: Wrap(
                direction: Axis.vertical,
                spacing: 32,
                alignment: WrapAlignment.spaceEvenly,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text("Playing Music and Lights..."),
                  CircularProgressIndicator(value: null,
                    valueColor: AlwaysStoppedAnimation(playbackColor))
                ],
              ),
            );
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

  @override
  void dispose() {
    super.dispose();
    canceled = true;
  }
}