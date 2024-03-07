import 'dart:io';

abstract class IDSEncoder implements IDisposable {
  late Stream RestWriter;

  List<int> ToArray();

  void ResetDsCurVal();

  void WriteDsClock(int clock);
  void WriteDsLength(int length);
}

abstract class IUpdateEncoder implements IDSEncoder {
  void WriteLeftId(ID id);
  void WriteRightId(ID id);

  void WriteClient(int client);

  void WriteInfo(int info);
  void WriteString(String s);
  void WriteParentInfo(bool isYKey);
  void WriteTypeRef(int info);

  void WriteLength(int len);

  void WriteAny(Object any);
  void WriteBuffer(List<int> buf);
  void WriteKey(String key);
  void WriteJson<T>(T any);
}