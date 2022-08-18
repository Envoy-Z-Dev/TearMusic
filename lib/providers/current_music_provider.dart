import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tearmusic/models/music/playlist.dart';
import 'package:tearmusic/models/music/track.dart';
import 'package:tearmusic/player/audio_source.dart';
import 'package:tearmusic/providers/music_info_provider.dart';

enum AudioLoadingState { ready, loading, error }
enum PlayingFrom { none, album, playlist }

class CurrentMusicProvider extends ChangeNotifier {
  CurrentMusicProvider({required MusicInfoProvider api}) : _api = api;

  final MusicInfoProvider _api;
  final player = AudioPlayer();
  AudioLoadingState audioLoading = AudioLoadingState.ready;
  PlayingFrom playingFrom = PlayingFrom.none;
  MusicTrack? playing;
  TearMusicAudioSource? tma;
  MusicPlaylist? playlist;

  double get progress => player.duration != null ? player.position.inMilliseconds / player.duration!.inMilliseconds : 0;

  // ! POC only
  Future<void> playTrack(MusicTrack track) async {
    player.stop();

    playing = track;
    audioLoading = AudioLoadingState.loading;
    notifyListeners();

    tma = TearMusicAudioSource(track, api: _api);
    final result = await tma!.head();

    if (result) {
      audioLoading = AudioLoadingState.ready;
    } else {
      audioLoading = AudioLoadingState.error;
    }
    notifyListeners();

    await player.setAudioSource(tma!);
    final silence = await tma!.silence();

    if (silence.isNotEmpty) {
      silence.sort((a, b) => a.start.compareTo(b.start));
      if (silence.first.start < const Duration(seconds: 1)) {
        log("-> ${silence.first.end}");
        player.seek(silence.first.end);
      }
    }

    player.play();

    if (!tma!.playback.isCompleted) await tma!.body();
  }
}
