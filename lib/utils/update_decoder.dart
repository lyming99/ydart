import 'dart:io';

abstract class IDSDecoder implements IDisposable {
  Stream get reader;

  void resetDsCurVal();
  int readDsClock();
  int readDsLength();
}

abstract class IUpdateDecoder implements IDSDecoder {
  ID readLeftId();
  ID readRightId();
  int readClient();
  int readInfo();
  String readString();
  bool readParentInfo();
  int readTypeRef();
  int readLength();
  dynamic readAny();
  List<int> readBuffer();
  String readKey();
  dynamic readJson();
}