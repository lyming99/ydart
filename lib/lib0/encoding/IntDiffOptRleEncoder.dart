import 'dart';

class IntDiffOptRleEncoder extends AbstractStreamEncoder {
    int _state = 0;
    int _diff = 0;
    int _count = 0;

    IntDiffOptRleEncoder() {
        // Do nothing.
    }

    @override
    void write(int value) {
        assert(value <= Bits.bits30);
        checkDisposed();

        if (_diff == value - _state) {
            _state = value;
            _count++;
        } else {
            writeEncodedValue();

            _count = 1;
            _diff = value - _state;
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
            int encodedDiff;
            if (_diff < 0) {
                encodedDiff = -(((_diff.abs() << 1) | (_count == 1 ? 0 : 1)));
            } else {
                encodedDiff = ((_diff << 1) | (_count == 1 ? 0 : 1));
            }

            stream.writeVarInt(encodedDiff);

            if (_count > 1) {
                stream.writeVarUint(_count - 2);
            }
        }
    }
}