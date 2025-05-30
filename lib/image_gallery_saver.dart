import 'dart:async';

import 'package:flutter/services.dart';

class ImageGallerySaver {
  static const MethodChannel _channel = const MethodChannel('image_gallery_saver');

  /// save image to Gallery
  /// imageBytes can't null
  /// return Map type
  /// for example:{"isSuccess":true, "filePath":String?}
  static FutureOr<dynamic> saveImage(Uint8List imageBytes, {String? name}) async {
    final result = await _channel.invokeMethod(
      'saveImageToGallery', <String, dynamic>{
        'imageBytes': imageBytes,
        'name': name
      }
    );
    return result;
  }

  /// save image to Download
  /// imageBytes can't null
  /// return Map type
  /// for example:{"isSuccess":true, "filePath":String?}
  static FutureOr<dynamic> saveImageToDownload(Uint8List imageBytes, String folder, String name) async {
    final result = await _channel.invokeMethod(
      'saveImageToDownload', <String, dynamic>{
        'imageBytes': imageBytes,
        'folder': folder,
        'name': name
      }
    );
    return result;
  }

  /// Save the PNG，JPG，JPEG image or video located at [file] to the local device media gallery.
  static Future saveFile(String file, {String? name}) async {
    final result = await _channel.invokeMethod(
      'saveFileToGallery', <String, dynamic>{
        'file': file,
        'name': name
      }
    );
    return result;
  }
}
