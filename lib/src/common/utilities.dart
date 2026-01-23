import 'dart:convert';

final _converter = const Utf8Decoder().fuse(const JsonDecoder());

Future<Object?> jsonStreamDecode(Stream<List<int>> stream) async =>
    _converter.bind(stream).first;

Future<Map<String, dynamic>> jsonStreamDecodeMap(
  Stream<List<int>> stream,
) async =>
    jsonStreamDecode(stream) as Future<Map<String, dynamic>>;
