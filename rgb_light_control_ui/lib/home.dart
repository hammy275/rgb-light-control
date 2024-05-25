import 'package:flutter/material.dart';
import 'package:rgb_light_control_ui/constants.dart';
import 'package:rgb_light_control_ui/light.dart';
import 'package:rgb_light_control_ui/lights_page.dart';
import 'package:rgb_light_control_ui/mode_page.dart';
import 'package:rgb_light_control_ui/playback_music.dart';
import 'package:rgb_light_control_ui/playback_rainbow.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }

}

class HomeState extends State<Home> {

  // Part of HomeState's state.
  int currentPageIndex = 0;
  final Set<Light> selectedLights = {};
  String selectedMode = "Rainbow";

  // Not part of HomeState's state.
  Widget? activePlaybackWidget;


  addLight(Light light) {
    setState(() {
      selectedLights.add(light);
    });
  }

  removeLight(Light light) {
    setState(() {
      selectedLights.remove(light);
    });
  }

  setMode(String newMode) {
    setState(() {
      selectedMode = newMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Constants.title), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: [LightsPage(lights: selectedLights, addLight: addLight, removeLight: removeLight),
        ModePage(selectedMode: selectedMode, setMode: setMode)][currentPageIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(context: context, builder: (BuildContext context) {
          List<String> lightNames = [];
          for (final light in selectedLights) {
            lightNames.add(light.name);
          }
          if (selectedMode == "Rainbow") {
            activePlaybackWidget = RainbowPlayback(lightNames: lightNames);
          } else {
            activePlaybackWidget = MusicPlayback(lightNames: lightNames);
          }
          return activePlaybackWidget!;
        }).whenComplete(() {
          activePlaybackWidget = null;
        }),
        label: const Text("Run Lights"),
        icon: const Icon(Icons.play_arrow)
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.lightbulb_outline), selectedIcon: Icon(Icons.lightbulb), label: "Lights"),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: "Mode")
        ],
        selectedIndex: currentPageIndex,
      ),
    );
  }

}