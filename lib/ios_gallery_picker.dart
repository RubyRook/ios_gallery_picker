library ios_gallery_picker;

import 'dart:io';
import 'package:flutter/services.dart';

final class MediaImage {
  final String id;
  final String path;
  final String name;
  final double width;
  final double height;

  MediaImage({
    required this.id,
    required this.path,
    required this.name,
    required this.width,
    required this.height,
  });

  Future<Uint8List?> getOriginBytes() async {
    final file = File(path);
    if (await file.exists()) return await file.readAsBytes();
    return null;
  }
}

class GalleryPicker {
  static const MethodChannel _channel = MethodChannel('ios_gallery_picker');

  static Future<List<MediaImage>> imagesPicker ({
    bool allowSelectGif = true,
    bool enableCamera = false,
    int maxSelectCount = 1,
  })
  async {
    Map<String, dynamic> arguments = {
      'allowSelectGif':allowSelectGif,
      'allowTakePhotoInLibrary':enableCamera,
      'maxSelectCount':maxSelectCount,
    };

    final media = <MediaImage>[];
    final data = await _channel.invokeMethod('imagesPicker', arguments);

    if (data is List) {
      for (final datum in data) {
        if (datum is Map) {
          media.add(MediaImage(
            id: datum['id'].toString(),
            path: datum['path'].toString(),
            name: datum['name'].toString(),
            width: (datum['width'] as int).toDouble(),
            height: (datum['height'] as int).toDouble(),
          ));
        }
      }
    }

    return media;
  }
}
