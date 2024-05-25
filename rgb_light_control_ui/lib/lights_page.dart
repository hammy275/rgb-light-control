import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rgb_light_control_ui/light.dart';

import 'constants.dart';

class LightsPage extends StatefulWidget {
  final Set<Light> lights;
  final ValueSetter<Light> addLight;
  final ValueSetter<Light> removeLight;
  const LightsPage({super.key, required this.lights, required this.addLight, required this.removeLight});

  @override
  State<StatefulWidget> createState() {
    return LightsPageState();
  }
}

class LightsPageState extends State<LightsPage> {

  late Future<List<Light>> futureLights;

  Future<List<Light>> getLights() async {
    final resp = await http.get(Uri.parse("${Constants.apiRoot}/get_lights"));
    if (resp.statusCode == 200) {
      final List<Light> lights = [];
      final data = jsonDecode(resp.body);
      for (final lightData in data["data"]) {
        lights.add(Light.fromJson(lightData));
      }
      return lights;
    } else {
      throw Exception("Failed to get lights");
    }
  }

  @override
  void initState() {
    super.initState();
    futureLights = getLights();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(future: futureLights, builder: (context, snapshot) {
      if (snapshot.hasData) {
        List<CheckboxListTile> checkboxes = [];
        for (final light in snapshot.data!) {
          checkboxes.add(CheckboxListTile(value: (widget.lights.contains(light)), title: Text(light.name),
            onChanged: (bool? value) {
            setState(() {
              if (value!) {
                widget.addLight(light);
              } else {
                widget.removeLight(light);
              }
            });
          }));
        }
        return ListView(
            children: checkboxes
        );
      } else if (snapshot.hasError) {
        return const Text("Failed to get the list of lights.");
      } else {
        return const CircularProgressIndicator();
      }
    });
  }
}