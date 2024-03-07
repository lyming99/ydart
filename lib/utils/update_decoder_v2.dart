import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:collection';

abstract class IDSDecoder {
  void dispose();
  void resetDsCurVal();
  int readDsClock();
  int readDsLength();
}

class DSDecoderV2 implements IDSDecoder {
  bool _leaveOpen;
  int _dsCurVal;
  Stream _reader;
  bool _disposed;

  DSDecoderV2(Stream input, {bool leaveOpen = false}) {
    _leaveOpen = leaveOpen;
    _reader = input;
    _disposed = false;
  }

  Stream get reader => _reader;

  @override
  void dispose() {
    _dispose(disposing: true);
    // System.GC.SuppressFinalize(this);
  }

  @override
  void resetDsCurVal() {
    _dsCurVal = 0;
  }

  @override
  int readDsClock() {
    _dsCurVal += _reader.readVarUint();
    assert(_dsCurVal >= 0);
    return _dsCurVal;
  }

  @override
  int readDsLength() {
    var diff = _reader.readVarUint() + 1;
    assert(diff >= 0);
    _dsCurVal += diff;
    return diff;
  }

  void _dispose({bool disposing}) {
    if (!_disposed) {
      if (disposing && !_leaveOpen) {
        _reader?.close();
      }

      _reader = null;
      _disposed = true;
    }
  }

  void checkDisposed() {
    if (_disposed) {
      throw ObjectDisposedException('DSDecoderV2');
    }
  }
}

class UpdateDecoderV2 extends DSDecoderV2 implements IUpdateDecoder {
  List<String> _keys;
  IntDiffOptRleDecoder _keyClockDecoder;
  UintOptRleDecoder _clientDecoder;
  IntDiffOptRleDecoder _leftClockDecoder;
  IntDiffOptRleDecoder _rightClockDecoder;
  RleDecoder _infoDecoder;
  StringDecoder _stringDecoder;
  RleDecoder _parentInfoDecoder;
  UintOptRleDecoder _typeRefDecoder;
  UintOptRleDecoder _lengthDecoder;

  UpdateDecoderV2(Stream input, {bool leaveOpen = false}) : super(input, leaveOpen: leaveOpen) {
    _keys = [];
    input.readByte();

    _keyClockDecoder = IntDiffOptRleDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
    _clientDecoder = UintOptRleDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
    _leftClockDecoder = IntDiffOptRleDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
    _rightClockDecoder = IntDiffOptRleDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
    _infoDecoder = RleDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
    _stringDecoder = StringDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
    _parentInfoDecoder = RleDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
    _typeRefDecoder = UintOptRleDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
    _lengthDecoder = UintOptRleDecoder(Uint8List.fromList(input.readVarUint8ArrayAsStream()));
  }

  @override
  ID readLeftId() {
    checkDisposed();
    return ID(_clientDecoder.read(), _leftClockDecoder.read());
  }

  @override
  ID readRightId() {
    checkDisposed();
    return ID(_clientDecoder.read(), _rightClockDecoder.read());
  }

  @override
  int readClient() {
    checkDisposed();
    return _clientDecoder.read();
  }

  @override
  int readInfo() {
    checkDisposed();
    return _infoDecoder.read();
  }

  @override
  String readString() {
    checkDisposed();
    return _stringDecoder.read();
  }

  @override
  bool readParentInfo() {
    checkDisposed();
    return _parentInfoDecoder.read() == 1;
  }

  @override
  int readTypeRef() {
    checkDisposed();
    return _typeRefDecoder.read();
  }

  @override
  int readLength() {
    checkDisposed();
    var value = _lengthDecoder.read();
    assert(value >= 0);
    return value;
  }

  @override
  dynamic readAny() {
    checkDisposed();
    var obj = reader.readAny();
    return obj;
  }

  @override
  Uint8List readBuffer() {
    checkDisposed();
    return reader.readVarUint8Array();
  }

  @override
  String readKey() {
    checkDisposed();
    var keyClock = _keyClockDecoder.read();
    if (keyClock < _keys.length) {
      return _keys[keyClock];
    } else {
      var key = _stringDecoder.read();
      _keys.add(key);
      return key;
    }
  }

  @override
  dynamic readJson() {
    checkDisposed();
    var jsonString = reader.readVarString();
    var result = json.decode(jsonString);
    return result;
  }

  @override
  void _dispose({bool disposing}) {
    if (!_disposed) {
      if (disposing) {
        _keyClockDecoder?.dispose();
        _clientDecoder?.dispose();
        _leftClockDecoder?.dispose();
        _rightClockDecoder?.dispose();
        _infoDecoder?.dispose();
        _stringDecoder?.dispose();
        _parentInfoDecoder?.dispose();
        _typeRefDecoder?.dispose();
        _lengthDecoder?.dispose();
      }

      _keyClockDecoder = null;
      _clientDecoder = null;
      _leftClockDecoder = null;
      _rightClockDecoder = null;
      _infoDecoder = null;
      _stringDecoder = null;
      _parentInfoDecoder = null;
      _typeRefDecoder = null;
      _lengthDecoder = null;
    }

    super._dispose(disposing: disposing);
  }
}