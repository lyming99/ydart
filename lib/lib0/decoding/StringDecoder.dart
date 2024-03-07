import 'dart:io';

import 'package:ydart/lib0/byte_input_stream.dart';

import 'IDecoder.dart';
import 'UintOptRleDecoder.dart';

class StringDecoder implements IDecoder<String> {
  late UintOptRleDecoder _lengthDecoder;
  late String _value;
  int _pos = 0;

  bool _disposed = false;

  StringDecoder(ByteArrayInputStream input, [bool leaveOpen = false]) {
    _lengthDecoder = UintOptRleDecoder(input, leaveOpen: leaveOpen);
    _value = input.readVarString();
  }

  void dispose() {
    _dispose(disposing: true);
  }

  @override
  String read() {
    _checkDisposed();
    var length = _lengthDecoder.read();
    if (length == 0) {
      return '';
    }

    var result = _value.substring(_pos, _pos + length);
    _pos += length;

    if (_pos >= _value.length) {
      _value = null;
    }

    return result;
  }

  void _dispose(bool disposing) {
    if (!_disposed) {
      if (disposing) {
        _lengthDecoder?.dispose();
      }

      _lengthDecoder = null;
      _disposed = true;
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw Exception(runtimeType.toString());
    }
  }
}
