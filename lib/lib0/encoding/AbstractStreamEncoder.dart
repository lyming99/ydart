import 'dart:typed_data';

abstract class AbstractStreamEncoder<T> implements IEncoder<T> {
    late Uint8List _stream;
    bool _disposed = false;

    AbstractStreamEncoder() {
        _stream = Uint8List(0);
    }

    void dispose() {
        _dispose(true);
        // System.GC.SuppressFinalize(this);
    }

    void write(T value);

    Uint8List toArray() {
        _flush();
        return _stream;
    }

    Tuple2<Uint8List, int> getBuffer() {
        _flush();
        return Tuple2(_stream.buffer.asUint8List(), _stream.length);
    }

    void _flush() {
        _checkDisposed();
    }

    void _dispose(bool disposing) {
        if (!_disposed) {
            if (disposing) {
                _stream = Uint8List(0);
            }

            _disposed = true;
        }
    }

    void _checkDisposed() {
        if (_disposed) {
            throw Exception('${runtimeType.toString()} is disposed');
        }
    }
}