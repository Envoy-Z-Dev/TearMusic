import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:tearmusic/models/music/lyrics.dart';
import 'package:tearmusic/models/music/track.dart';
import 'package:tearmusic/providers/current_music_provider.dart';
import 'package:tearmusic/providers/music_info_provider.dart';
import 'package:tearmusic/providers/theme_provider.dart';
import 'package:tearmusic/ui/mobile/common/player/lyrics_view/unavailable.dart';
import 'package:tearmusic/ui/mobile/common/player/lyrics_view/full_text.dart';
import 'package:tearmusic/ui/mobile/common/player/lyrics_view/subtitle.dart';
import 'package:tearmusic/ui/mobile/common/player/lyrics_view/rich_sync.dart';

class LyricsView extends StatefulWidget {
  const LyricsView(this.track, {Key? key}) : super(key: key);

  final MusicTrack track;

  static Future<void> view(MusicTrack value, {required BuildContext context}) => Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(builder: (context) => LyricsView(value), fullscreenDialog: true),
      );

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> with SingleTickerProviderStateMixin {
  final ScrollController _controller = ScrollController();
  List<List<bool>> actives = [];
  double lastPos = 0.0;
  bool autoScroll = true;
  Timer scrollTimer = Timer(Duration.zero, () {});
  late StreamSubscription<Duration> progressSub;
  List<TimedSegment>? lSub;
  List<LyricsLine>? lRich;

  void scrollListener() {
    autoScroll = false;
    scrollTimer.cancel();
    scrollTimer = Timer(const Duration(seconds: 3), () => autoScroll = true);
  }

  void progressListener(Duration event) {
    double height = 0;
    if (lRich != null) {
      for (var line in lRich!) {
        if (line.start.inMilliseconds > event.inMilliseconds) break;
        final span = TextSpan(
          text: line.segments.map((e) => e.text).join(),
          style: TextStyle(
            fontFamily: ThemeProvider.defaultTheme.textTheme.bodyText2!.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 22.0,
          ),
        );
        final painter = TextPainter(text: span, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
        painter.layout(maxWidth: MediaQuery.of(context).size.width - 28.0 * 2);
        height += painter.height + 14.0 * 2;
      }
    } else if (lSub != null) {
      for (var line in lSub!) {
        if (line.offset.inMilliseconds > event.inMilliseconds) break;
        final span = TextSpan(
          text: line.text,
          style: TextStyle(
            fontFamily: ThemeProvider.defaultTheme.textTheme.bodyText2!.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 22.0,
          ),
        );
        final painter = TextPainter(text: span, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
        painter.layout(maxWidth: MediaQuery.of(context).size.width - 28.0 * 2);
        height += painter.height + 14.0 * 2;
      }
    }

    if (_controller.positions.isNotEmpty) {
      height = (height + 200 - MediaQuery.of(context).size.height / 2).clamp(0, _controller.position.maxScrollExtent);
      if (lastPos == 0) {
        _controller.jumpTo(height);
        autoScroll = true;
      } else if (height != lastPos && autoScroll) {
        _controller.animateTo(height, duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
        autoScroll = true;
      }
      lastPos = height;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(scrollListener);

    final currentMusic = context.read<CurrentMusicProvider>();
    progressSub = currentMusic.player.positionStream.distinct().listen(progressListener);
  }

  @override
  void dispose() {
    progressSub.cancel();
    _controller.removeListener(scrollListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<MusicLyrics>(
        future: context.read<MusicInfoProvider>().lyrics(widget.track),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Theme.of(context).colorScheme.secondary.withOpacity(.2),
                size: 64.0,
              ),
            );
          }

          // final dataLength = snapshot.data!.richSync?.length ?? snapshot.data!.subtitle?.length ?? 0;

          // if (actives.isEmpty) {
          //   actives = List.generate(dataLength, (index) {
          //     if (snapshot.data!.richSync != null) {
          //       final line = snapshot.data!.richSync!.elementAt(index);
          //       return List.generate(line.segments.length,
          //           (i) => (line.start + line.segments[i].offset).inMilliseconds / widget.track.duration.inMilliseconds > animation.value);
          //     }
          //     if (snapshot.data!.subtitle != null) {
          //       return [animation.value > snapshot.data!.subtitle!.elementAt(index).offset.inMilliseconds / widget.track.duration.inMilliseconds];
          //     }
          //     return [false];
          //   });
          // }

          lSub = snapshot.data!.subtitle;
          lRich = snapshot.data!.richSync;

          return Stack(
            children: [
              CustomScrollView(
                controller: _controller,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: 200 + MediaQuery.of(context).padding.top),
                  ),
                  if (snapshot.data!.lyricsType == LyricsType.unavailable)
                    const SliverToBoxAdapter(
                      child: LyricsUnavailalbe(),
                    ),
                  if (snapshot.data!.lyricsType == LyricsType.fullText)
                    SliverToBoxAdapter(
                      child: LyricsFullText(snapshot.data!.fullText!),
                    ),
                  if (snapshot.data!.lyricsType == LyricsType.subtitle)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        childCount: snapshot.data!.subtitle!.length,
                        subtitleListBuilder(snapshot.data!.subtitle!, widget.track),
                      ),
                    ),
                  if (snapshot.data!.lyricsType == LyricsType.richsync)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        childCount: snapshot.data!.richSync!.length,
                        richSyncListBuilder(snapshot.data!.richSync!, widget.track),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: 200 + MediaQuery.of(context).padding.bottom),
                  ),
                ],
              ),
              if (snapshot.data!.lyricsType != LyricsType.unavailable)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, .3, .6, 1],
                          colors: [
                            Theme.of(context).scaffoldBackgroundColor.withOpacity(.7),
                            Theme.of(context).scaffoldBackgroundColor.withOpacity(0),
                            Theme.of(context).scaffoldBackgroundColor.withOpacity(0),
                            Theme.of(context).scaffoldBackgroundColor.withOpacity(.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (snapshot.data!.lyricsType != LyricsType.unavailable)
                const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: BackButton(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
