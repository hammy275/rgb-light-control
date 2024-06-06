import 'package:flutter/material.dart';
import 'package:rgb_light_control_ui/constants.dart';
import 'package:rgb_light_control_ui/light.dart';
import 'package:rgb_light_control_ui/lights_page.dart';
import 'package:rgb_light_control_ui/mode_page.dart';
import 'package:rgb_light_control_ui/playback_music.dart';
import 'package:rgb_light_control_ui/playback_rainbow.dart';
import 'package:rgb_light_control_ui/settings.dart';

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
  int page0RefreshCounter = 0;  // Increment to reset the state of page0.
  final RainbowSettings rainbowSettings = RainbowSettings();
  final MusicSettings musicSettings = MusicSettings();


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

  String areSettingsValid() {
    /// Returns an empty string if settings are valid, or an error message if not.
    if (selectedLights.isEmpty) {
      return "At least one light must be selected.";
    }
    if (["Cycle to Music", "Fade with Music"].contains(selectedMode)) {
      if (musicSettings.musicFile == null) {
        return "A music file must be selected.";
      }
    }
    if (selectedMode == "Fade with Music") {
      if (musicSettings.colors.length != 2) {
        return "Exactly two colors must be selected for 'Fade with Music'.";
      }
    } else if (selectedMode == "Cycle to Music") {
      if (musicSettings.colors.length < 2) {
        return "Please select at least two colors for 'Cycle to Music'.";
      }
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];
    if (currentPageIndex == 0) {
      actions.add(IconButton(onPressed: () => setState(() => page0RefreshCounter++), icon: const Icon(Icons.refresh)));
    }
    String cantStartError = areSettingsValid();
    return Scaffold(
      appBar: AppBar(title: const Text(Constants.title), backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: actions),
      body: IndexedStack(
        index: currentPageIndex,
        children: [LightsPage(key: ValueKey(page0RefreshCounter), lights: selectedLights, addLight: addLight, removeLight: removeLight),
          ModePage(selectedMode: selectedMode, setMode: setMode, rainbowSettings: rainbowSettings,
            musicSettings: musicSettings)]
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(context: context,
        builder: (BuildContext context) {
          if (cantStartError.isNotEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(style: Theme.of(context).textTheme.titleLarge, cantStartError),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Ok")
                  )
                )
              ],
            );
          } else {
            List<String> lightNames = [];
            for (final light in selectedLights) {
              lightNames.add(light.name);
            }
            if (selectedMode == "Rainbow") {
              return RainbowPlayback(lightNames: lightNames, settings: rainbowSettings);
            } else {
              return MusicPlayback(lightNames: lightNames, modeName: selectedMode, settings: musicSettings,);
            }
          }
        }),
        label: const Text("Run Lights"),
        icon: const Icon(Icons.play_arrow)
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationBar(
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
          )
        ],
      ),
    );
  }

}