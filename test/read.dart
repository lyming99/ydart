import 'dart:io';

import 'package:ydart/utils/y_doc.dart';

void main(){
  var file = "/Users/liyuanming/Library/Containers/cn.wennote.app/Data/Documents/user-1/notes/d58a1d70-bacb-11ee-8511-951f7b79a2c3.wnote";
  var bytes = File(file).readAsBytesSync();
  var doc = YDoc();
  doc.applyUpdateV2(bytes);
}