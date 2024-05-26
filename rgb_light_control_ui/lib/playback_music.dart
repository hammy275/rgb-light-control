import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';

class MusicPlayback extends StatefulWidget {

  final List<String> lightNames;
  final String modeName;

  const MusicPlayback({super.key, required this.lightNames, required this.modeName});

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

  late Future<double> futureSendDelay;
  int hValue = 0;

  Future<double> estimateLightSendDelay() async {
    final stopwatch = Stopwatch();
    stopwatch.start();
    final resp = await http.post(Uri.parse("${Constants.apiRoot}/estimate_light_delay"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"lights": widget.lightNames})
    );
    stopwatch.stop();
    final double approximateRequestTime = stopwatch.elapsed.inMilliseconds / 1000 / 2;
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data["data"] + approximateRequestTime;
    } else {
      throw Exception("Failed to get light send delay ${resp.body}");
    }
  }

  @override
  void initState() {
    super.initState();
    futureSendDelay = estimateLightSendDelay();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(future: futureSendDelay, builder: (context, snapshot) {
      if (snapshot.hasData) {
        return const Text("Unimplemented");
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
              Text("Calculating Color Set Delay..."),
              CircularProgressIndicator(value: null)
            ],
          ),
        );
      }
    });
  }
}