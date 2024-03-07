import 'dart:typed_data';

class StringEncoder implements IEncoder<String> {
    late StringBuffer _sb;
    late UintOptRleEncoder _lengthEncoder;
    bool _disposed = false;

    StringEncoder() {
        _sb = StringBuffer();
        _lengthEncoder = UintOptRleEncoder();
    }

    @override
    void dispose() {
        _dispose(true);
        // System.GC.SuppressFinalize(this);
    }

    @override
    void write(String value) {
        _sb.write(value);
        _lengthEncoder.write(value.length);
    }

    void writeChars(List<int> value, int offset, int count) {
        _sb.write(String.fromCharCodes(value, offset, offset + count));
        _lengthEncoder.write(count);
    }

    Uint8List toArray() {
        var byteData = utf8.encode(_sb.toString());
        var lengthData = _lengthEncoder.getBuffer();
        var result = Uint8List(byteData.length + lengthData.length);
        result.setAll(0, byteData);
        result.setAll(byteData.length, lengthData);
        return result;
    }

    void _dispose(bool disposing) {
        if (!_disposed) {
            if (disposing) {
                _sb.clear();
                _lengthEncoder.dispose();
            }

            _sb = StringBuffer();
            _lengthEncoder = UintOptRleEncoder();
            _disposed = true;
        }
    }

    void checkDisposed() {
        if (_disposed) {
            throw Exception('${runtimeType.toString()} is disposed');
        }
    }
}