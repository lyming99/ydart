import 'AbstractStreamDecoder.dart';

class RleIntDiffDecoder extends AbstractStreamDecoder<int> {
  int _state = 0;
  int _count = 0;

  RleIntDiffDecoder(super.input, int start, {super.leaveOpen = false}) {
    _state = start;
  }

  @override
  int read() {
    checkDisposed();

    if (_count == 0) {
      _state += readVarInt(stream);

      if (hasContent) {
        _count = readVarUint(stream) + 1;
        assert(_count > 0);
      } else {
        // Read the current value forever.
        _count = -1;
      }
    }

    _count--;
    return _state;
  }
}
