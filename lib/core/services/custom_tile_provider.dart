import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';

class RetryTileProvider extends TileProvider {
  RetryTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = options.urlTemplate ?? '';
    return _RetryNetworkImage(
      url
        .replaceAll('{x}', coordinates.x.round().toString())
        .replaceAll('{y}', coordinates.y.round().toString())
        .replaceAll('{z}', coordinates.z.round().toString()),
    );
  }
}

class _RetryNetworkImage extends ImageProvider<_RetryNetworkImage> {
  final String url;

  const _RetryNetworkImage(this.url);

  @override
  Future<_RetryNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_RetryNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(_RetryNetworkImage key, ImageDecoderCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      informationCollector: () => [
        ErrorDescription('Image provider: $key'),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    _RetryNetworkImage key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    const retryOptions = RetryOptions(
      maxAttempts: 3,
      delayFactor: Duration(milliseconds: 200),
    );

    try {
      final uri = Uri.parse(key.url);
      final response = await retryOptions.retry(
        () => http.get(uri).timeout(const Duration(seconds: 15)),
        retryIf: (e) => e is SocketException || e is TimeoutException,
      );

      if (response.statusCode != 200) {
        throw NetworkImageLoadException(statusCode: response.statusCode, uri: uri);
      }

      final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
      return decode(buffer);
    } catch (e) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RetryNetworkImage && url == other.url;

  @override
  int get hashCode => url.hashCode;
}