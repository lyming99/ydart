﻿import 'dart:typed_data';

import 'package:ydart/lib0/byte_output_stream.dart';

import 'IEncoder.dart';

abstract class AbstractStreamEncoder<T> implements IEncoder<T> {
    late ByteArrayOutputStream stream;
    bool _disposed = false;

    AbstractStreamEncoder() {
        stream = ByteArrayOutputStream(32);
    }

    void dispose() {
        _dispose(true);
        // System.GC.SuppressFinalize(this);
    }

    void write(T value);

    Uint8List toArray() {
        _flush();
        return stream.toByteArray();
    }

    Uint8List getBuffer() {
        _flush();
        return stream.toByteArray();
    }

    void _flush() {
        _checkDisposed();
    }

    void _dispose(bool disposing) {
        if (!_disposed) {
            if (disposing) {
                stream = ByteArrayOutputStream();
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