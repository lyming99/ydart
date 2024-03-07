import 'dart:io';

import 'AbstractStreamDecoder.dart';

class UintOptRleDecoder extends AbstractStreamDecoder<int> {
  int _state = 0;
  int _count = 0;

  UintOptRleDecoder(super.input, {super.leaveOpen});

  @override
  int read() {
    checkDisposed();

    if (_count == 0) {
      var valueAndSign = stream.readVarInt();
      int value = valueAndSign[0];
      int sign = valueAndSign[1];

      bool isNegative = sign < 0;
      if (isNegative) {
        _state = -value;
        _count = stream.readVarUint() + 2;
      } else {
        _state = value;
        _count = 1;
      }
    }

    _count--;
    return _state;
  }
}
