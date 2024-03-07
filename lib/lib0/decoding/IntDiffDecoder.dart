import 'dart:io';

import 'package:ydart/lib0/byte_input_stream.dart';

import 'AbstractStreamDecoder.dart';

class IntDiffDecoder extends AbstractStreamDecoder {
  late int _state;

  IntDiffDecoder(ByteArrayInputStream input, int start,
      {bool leaveOpen = false})
      : super(input, leaveOpen: leaveOpen) {
    _state = start;
  }

  @override
  int read() {
    checkDisposed();
    _state += stream.readVarInt();
    return _state;
  }
}
