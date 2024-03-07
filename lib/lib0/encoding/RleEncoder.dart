// ------------------------------------------------------------------------------
//  <copyright company="Microsoft Corporation">
//      Copyright (c) Microsoft Corporation.  All rights reserved.
//  </copyright>
// ------------------------------------------------------------------------------

import 'abstract_stream_encoder.dart';

/// Basic Run Length Encoder - a basic compression implementation.
/// Encodes [1, 1, 1, 7] to [1, 3, 7, 1] (3 times '1', 1 time '7').
/// This encoder might do more harm than good if there are a lot of values that are not repeated.
/// It was originally used for image compression.
class RleEncoder extends AbstractStreamEncoder<int> {
    int? _state;
    int _count = 0;

    RleEncoder() {
        // Do nothing.
    }

    @override
    void write(int value) {
        checkDisposed();

        if (_state == value) {
            _count++;
        } else {
            if (_count > 0) {
                // Flush counter, unless this is the first value (count = 0).
                // Since 'count' is always >0, we can decrement by one. Non-standard encoding.
                stream.writeVarUint(_count - 1);
            }

            stream.writeByte(value);

            _count = 1;
            _state = value;
        }
    }
}