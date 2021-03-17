import 'package:flutter/material.dart';
import 'package:flutter_sound_suite/flutter_sound_suite.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(FlutterSoundSuiteApp());
}

class FlutterSoundSuiteApp extends StatefulWidget {
  @override
  _FlutterSoundSuiteAppState createState() => _FlutterSoundSuiteAppState();
}

class _FlutterSoundSuiteAppState extends State<FlutterSoundSuiteApp> {
  List<Map> data = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Sound Suite Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Sound Suite Demo'),
        ),
        body: ChangeNotifierProvider(
          create: (context) => SoundPlayerModel(),
          child: Container(
            child: ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                Map item = data[index];
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['fileName']),
                      Text('duration ${item['duration']}'),
                      Card(
                        color: Colors.red.shade50,
                        child: SoundPlayerWidget(
                          filePath: item['filePath'],
                          fileName: item['fileName'],
                          duration: item['duration'],
                        ),
                      ),
                    ],
                  ),
                );
              },
              itemCount: data.length,
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 70,
            child: SoundRecorderWidget(recordComplete:
                (String filePath, String fileName, double duration) {
              setState(() {
                data.add({
                  'filePath': filePath,
                  'fileName': fileName,
                  'duration': duration,
                });
                debugPrint('save to $filePath duration $duration');
              });
            }),
          ),
        ),
      ),
    );
  }
}
