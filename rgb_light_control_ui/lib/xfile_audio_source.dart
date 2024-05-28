import 'package:file_selector/file_selector.dart';
import 'package:just_audio/just_audio.dart';

class XFileAudioSource extends StreamAudioSource {

  final XFile audioFile;

  XFileAudioSource(this.audioFile);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    int length = await audioFile.length();
    start = start ?? 0;
    end = end ?? length;
    return StreamAudioResponse(
      sourceLength: length,
      contentLength: end - start,
      offset: start,
      stream: Stream.fromIterable([(await audioFile.readAsBytes()).sublist(start, end)]),
      contentType: 'audio/mp3',
    );
  }
}