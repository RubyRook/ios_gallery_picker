library ios_gallery_picker;

import 'dart:io';
import 'package:flutter/services.dart';

/// For more info: `https://developer.apple.com/documentation/photokit/phimagerequestoptionsdeliverymode`
enum DeliveryMode {opportunistic, highQualityFormat, fastFormat}

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
  GalleryPicker._();

  static final instance = GalleryPicker._();

  final _channel = const MethodChannel('ios_gallery_picker');

  List<MediaImage> _setupImage(var data) {
    final listMedia = <MediaImage>[];

    if (data is List) {
      for (final datum in data) {
        if (datum is Map) {
          final media = MediaImage(
            id: datum['id'].toString(),
            path: datum['path'].toString(),
            name: datum['name'].toString(),
            width: (datum['width'] as int).toDouble(),
            height: (datum['height'] as int).toDouble(),
          );

          listMedia.add(media);
        }
      }
    }

    return listMedia;
  }

  Future<List<MediaImage>> imagesPickerAsset ({
    bool allowSelectGif = true,
    bool enableCamera = false,
    int maxSelectCount = 1,
    int columnCount = 4,
    DeliveryMode deliveryMode = DeliveryMode.opportunistic,
  })
  async {
    Map<String, dynamic> arguments = {
      'allowSelectGif':allowSelectGif,
      'allowTakePhotoInLibrary':enableCamera,
      'maxSelectCount':maxSelectCount,
      'columnCount':columnCount,
      'deliveryMode':deliveryMode.index,
    };

    final data = await _channel.invokeMethod('imagesPickerAsset', arguments);
    return _setupImage(data);
  }
}
