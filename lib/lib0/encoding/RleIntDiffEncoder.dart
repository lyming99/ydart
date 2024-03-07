import 'dart';

class RleIntDiffEncoder extends AbstractStreamEncoder {
    int _state;
    int _count;

    RleIntDiffEncoder(int start) {
        _state = start;
    }

    @override
    void write(int value) {
        checkDisposed();

        if (_state == value && _count > 0) {
            _count++;
        } else {
            if (_count > 0) {
                stream.writeVarUint(_count - 1);
            }

            stream.writeVarInt(value - _state);

            _count = 1;
            _state = value;
        }
    }
}