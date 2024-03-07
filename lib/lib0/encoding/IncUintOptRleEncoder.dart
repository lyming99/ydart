import 'dart';

class IncUintOptRleEncoder extends AbstractStreamEncoder {
    int _state;
    int _count;

    IncUintOptRleEncoder() {
        // Do nothing.
    }

    @override
    void write(int value) {
        assert(value <= int.maxValue);
        checkDisposed();

        if (_state + _count == value) {
            _count++;
        } else {
            writeEncodedValue();

            _count = 1;
            _state = value;
        }
    }

    @override
    void flush() {
        writeEncodedValue();
        super.flush();
    }

    void writeEncodedValue() {
        if (_count > 0) {
            if (_count == 1) {
                stream.writeVarInt(_state);
            } else {
                stream.writeVarInt(-_state, treatZeroAsNegative: _state == 0);
                stream.writeVarUint(_count - 2);
            }
        }
    }
}