import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart'
    show CompressFormat, FlutterImageCompress;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class JournalImageStore {
  static const maxImages = 3;

  static Future<List<String>> persistPicks(List<XFile> picks) async {
    if (picks.isEmpty) return const [];

    final dir = await getApplicationDocumentsDirectory();
    final journalDir = Directory(p.join(dir.path, 'journal_images'));
    if (!await journalDir.exists()) {
      await journalDir.create(recursive: true);
    }

    final paths = <String>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < picks.length; i++) {
      final src = File(picks[i].path);
      if (!await src.exists()) continue;
      final dest = File(p.join(journalDir.path, '${stamp}_$i.jpg'));
      final compressed = await FlutterImageCompress.compressAndGetFile(
        src.path,
        dest.path,
        minWidth: 1600,
        minHeight: 1600,
        quality: 82,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (compressed != null) {
        paths.add(compressed.path);
      } else {
        final ext = p.extension(picks[i].path);
        final fallback = File(p.join(journalDir.path, '${stamp}_$i$ext'));
        await src.copy(fallback.path);
        paths.add(fallback.path);
      }
    }
    return paths;
  }
}
