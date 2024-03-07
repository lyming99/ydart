import 'dart:typed_data';

abstract class IEncoder<T> {
    void write(T value);

    Uint8List toArray();

    Tuple2<Uint8List, int> getBuffer();
}