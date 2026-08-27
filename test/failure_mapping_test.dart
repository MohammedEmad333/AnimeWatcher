import 'package:anime_watcher/core/error/exceptions.dart';
import 'package:anime_watcher/core/error/failures.dart';
import 'package:anime_watcher/shared/models/stream_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Failure.fromException', () {
    test('maps NetworkException to NetworkFailure', () {
      final failure = Failure.fromException(const NetworkException());
      expect(failure, isA<NetworkFailure>());
    });

    test('maps TimeoutException to TimeoutFailure', () {
      final failure = Failure.fromException(const TimeoutException());
      expect(failure, isA<TimeoutFailure>());
    });

    test('maps ServerException to ServerFailure with status code', () {
      final failure = Failure.fromException(
        const ServerException('boom', statusCode: 500),
      );
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 500);
    });

    test('maps unknown errors to UnknownFailure', () {
      final failure = Failure.fromException(Exception('???'));
      expect(failure, isA<UnknownFailure>());
    });

    test('asFailure extension passes existing Failures through', () {
      const original = NetworkFailure();
      expect(original.asFailure, same(original));
    });
  });

  group('StreamFormat.fromValue', () {
    test('detects HLS from explicit value', () {
      expect(StreamFormat.fromValue('hls', ''), StreamFormat.hls);
      expect(StreamFormat.fromValue('m3u8', ''), StreamFormat.hls);
    });

    test('infers HLS from .m3u8 url when value is absent', () {
      expect(
        StreamFormat.fromValue(null, 'https://cdn/x/stream.m3u8'),
        StreamFormat.hls,
      );
    });

    test('defaults to mp4', () {
      expect(
        StreamFormat.fromValue(null, 'https://cdn/x/video.mp4'),
        StreamFormat.mp4,
      );
    });
  });
}
