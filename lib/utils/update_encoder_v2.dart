import 'dart:typed_data';

abstract class IDSEncoder {
  void Dispose();
  void ResetDsCurVal();
  void WriteDsClock(int clock);
  void WriteDsLength(int length);
  List<int> ToArray();
}

class DSEncoderV2 implements IDSEncoder {
  late int _dsCurVal;
  late ByteData restWriter;
  bool disposed = false;

  DSEncoderV2() {
    _dsCurVal = 0;
    restWriter = ByteData(0);
  }

  @override
  void Dispose() {
    _dispose(disposing: true);
    // System.GC.SuppressFinalize(this);
  }

  @override
  void ResetDsCurVal() {
    _dsCurVal = 0;
  }

  @override
  void WriteDsClock(int clock) {
    int diff = clock - _dsCurVal;
    assert(diff >= 0);
    _dsCurVal = clock;
    // RestWriter.WriteVarUint((uint)diff);
  }

  @override
  void WriteDsLength(int length) {
    if (length <= 0) {
      throw ArgumentError();
    }

    // RestWriter.WriteVarUint((uint)(length - 1));
    _dsCurVal += length;
  }

  @override
  List<int> ToArray() {
    // return ((MemoryStream)RestWriter).ToArray();
    return [];
  }

  void _dispose({required bool disposing}) {
    if (!disposed) {
      if (disposing) {
        // RestWriter.Dispose();
      }

      // RestWriter = null;
      disposed = true;
    }
  }
}

abstract class IUpdateEncoder {
  void WriteLeftId(ID id);
  void WriteRightId(ID id);
  void WriteClient(int client);
  void WriteInfo(int info);
  void WriteString(String s);
  void WriteParentInfo(bool isYKey);
  void WriteTypeRef(int info);
  void WriteLength(int len);
  void WriteAny(Object any);
  void WriteBuffer(Uint8List data);
  void WriteKey(String key);
  void WriteJson<T>(T any);
}

class UpdateEncoderV2 extends DSEncoderV2 implements IUpdateEncoder {
  late int _keyClock;
  late Map<String, int> _keyMap;
  late IntDiffOptRleEncoder _keyClockEncoder;
  late UintOptRleEncoder _clientEncoder;
  late IntDiffOptRleEncoder _leftClockEncoder;
  late IntDiffOptRleEncoder _rightClockEncoder;
  late RleEncoder _infoEncoder;
  late StringEncoder _stringEncoder;
  late RleEncoder _parentInfoEncoder;
  late UintOptRleEncoder _typeRefEncoder;
  late UintOptRleEncoder _lengthEncoder;

  UpdateEncoderV2() {
    _keyClock = 0;
    _keyMap = {};
    _keyClockEncoder = IntDiffOptRleEncoder();
    _clientEncoder = UintOptRleEncoder();
    _leftClockEncoder = IntDiffOptRleEncoder();
    _rightClockEncoder = IntDiffOptRleEncoder();
    _infoEncoder = RleEncoder();
    _stringEncoder = StringEncoder();
    _parentInfoEncoder = RleEncoder();
    _typeRefEncoder = UintOptRleEncoder();
    _lengthEncoder = UintOptRleEncoder();
  }

  @override
  List<int> ToArray() {
    // using (var stream = new MemoryStream())
    // {
    //   stream.WriteByte(0);
    //   stream.WriteVarUint8Array(_keyClockEncoder.ToArray());
    //   stream.WriteVarUint8Array(_clientEncoder.ToArray());
    //   stream.WriteVarUint8Array(_leftClockEncoder.ToArray());
    //   stream.WriteVarUint8Array(_rightClockEncoder.ToArray());
    //   stream.WriteVarUint8Array(_infoEncoder.ToArray());
    //   stream.WriteVarUint8Array(_stringEncoder.ToArray());
    //   stream.WriteVarUint8Array(_parentInfoEncoder.ToArray());
    //   stream.WriteVarUint8Array(_typeRefEncoder.ToArray());
    //   stream.WriteVarUint8Array(_lengthEncoder.ToArray());
    //   var content = base.ToArray();
    //   stream.Write(content, 0, content.Length);
    //   return stream.ToArray();
    // }
    return [];
  }

  @override
  void WriteLeftId(ID id) {
    _clientEncoder.Write(id.Client);
    _leftClockEncoder.Write(id.Clock);
  }

  @override
  void WriteRightId(ID id) {
    _clientEncoder.Write(id.Client);
    _rightClockEncoder.Write(id.Clock);
  }

  @override
  void WriteClient(int client) {
    _clientEncoder.Write(client);
  }

  @override
  void WriteInfo(int info) {
    _infoEncoder.Write(info);
  }

  @override
  void WriteString(String s) {
    _stringEncoder.Write(s);
  }

  @override
  void WriteParentInfo(bool isYKey) {
    _parentInfoEncoder.Write(isYKey ? 1 : 0);
  }

  @override
  void WriteTypeRef(int info) {
    _typeRefEncoder.Write(info);
  }

  @override
  void WriteLength(int len) {
    assert(len >= 0);
    _lengthEncoder.Write(len);
  }

  @override
  void WriteAny(Object any) {
    // RestWriter.WriteAny(any);
  }

  @override
  void WriteBuffer(Uint8List data) {
    // RestWriter.WriteVarUint8Array(data);
  }

  @override
  void WriteKey(String key) {
    _keyClockEncoder.Write(_keyClock++);
    if (!_keyMap.containsKey(key)) {
      _stringEncoder.Write(key);
    }
  }

  @override
  void WriteJson<T>(T any) {
    // var jsonString = Newtonsoft.Json.JsonConvert.SerializeObject(any, typeof(T), null);
    // RestWriter.WriteVarString(jsonString);
  }

  void _dispose({required bool disposing}) {
    if (!disposed) {
      if (disposing) {
        _keyMap.clear();
        _keyClockEncoder.Dispose();
        _clientEncoder.Dispose();
        _leftClockEncoder.Dispose();
        _rightClockEncoder.Dispose();
        _infoEncoder.Dispose();
        _stringEncoder.Dispose();
        _parentInfoEncoder.Dispose();
        _typeRefEncoder.Dispose();
        _lengthEncoder.Dispose();
      }

      _keyMap = {};
      _keyClockEncoder = IntDiffOptRleEncoder();
      _clientEncoder = UintOptRleEncoder();
      _leftClockEncoder = IntDiffOptRleEncoder();
      _rightClockEncoder = IntDiffOptRleEncoder();
      _infoEncoder = RleEncoder();
      _stringEncoder = StringEncoder();
      _parentInfoEncoder = RleEncoder();
      _typeRefEncoder = UintOptRleEncoder();
      _lengthEncoder = UintOptRleEncoder();
    }

    super._dispose(disposing: disposing);
  }
}

class ID {
  late int Client;
  late int Clock;

  ID(this.Client, this.Clock);
}

class IntDiffOptRleEncoder {
  void Write(int value) {}
  void Dispose() {}
}

class UintOptRleEncoder {
  void Write(int value) {}
  void Dispose() {}
}

class RleEncoder {
  void Write(int value) {}
  void Dispose() {}
}

class StringEncoder {
  void Write(String s) {}
  void Dispose() {}
}