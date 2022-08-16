import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tearmusic/models/music/track.dart';
import 'package:tearmusic/providers/current_music_provider.dart';
import 'package:tearmusic/providers/music_info_provider.dart';
import 'package:tearmusic/providers/navigator_provider.dart';
import 'package:tearmusic/providers/theme_provider.dart';
import 'package:tearmusic/ui/common/image_color.dart';
import 'package:tearmusic/ui/mobile/common/cached_image.dart';
import 'package:tearmusic/ui/common/format.dart';
import 'package:tearmusic/ui/mobile/common/views/album_view/album_view.dart';
import 'package:tearmusic/ui/mobile/common/views/artist_view.dart';

class TrackTile extends StatelessWidget {
  const TrackTile(this.track, {Key? key, this.leadingTrackNumber = false, this.trailingDuration = false}) : super(key: key);

  final MusicTrack track;
  final bool leadingTrackNumber;
  final bool trailingDuration;

  @override
  Widget build(BuildContext context) {
    return CupertinoContextMenu(
      actions: [
        CupertinoContextMenuAction(
          child: const Text("View Artist"),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            Future.delayed(const Duration(seconds: 1)).then((_) {
              ArtistView.view(track.artists.first, context: context);
            });
          },
        ),
        if (track.album != null)
          CupertinoContextMenuAction(
            child: const Text("View Album"),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Future.delayed(const Duration(seconds: 1)).then((_) {
                AlbumView.view(track.album!, context: context);
              });
            },
          ),
        CupertinoContextMenuAction(
          child: const Text("Purge Cache"),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            context.read<MusicInfoProvider>().purgeCache(track);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<NavigatorProvider>().showSnackBar(const SnackBar(content: Text("Track cache deleted")));
            });
          },
        ),
      ],
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: leadingTrackNumber
              ? SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Text(
                      track.trackNumber.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  width: 42,
                  height: 42,
                  child: track.album != null && track.album!.images != null ? CachedImage(track.album!.images!, size: const Size(64, 64)) : null,
                ),
          title: Text(
            track.name,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              if (track.explicit)
                Container(
                  margin: const EdgeInsets.only(right: 6.0),
                  height: 14,
                  width: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.0),
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  child: Center(
                    child: Text(
                      "E",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        fontSize: 12.0,
                        height: -0.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  track.artistsLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: trailingDuration ? Text(track.duration.shortFormat()) : null,
          visualDensity: VisualDensity.compact,
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
            final currentMusic = context.read<CurrentMusicProvider>();
            if (track.album?.images != null) {
              CachedImage(track.album!.images!).getImage(const Size(64, 64)).then((value) {
                final colors = generateColorPalette(value);
                final theme = context.read<ThemeProvider>();
                if (theme.key != colors[1]) theme.setThemeKey(colors[1]);
                currentMusic.playTrack(track);
              });
            }
          },
        ),
      ),
    );
  }
}
