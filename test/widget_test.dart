import 'package:ydart/utils/y_doc.dart';

void main() {
  var doc = YDoc(YDocOptions());
  var doc2 = YDoc(YDocOptions());
  doc.updateV2.add((data, origin, transaction) {
    doc2.applyUpdateV2(data);
    print("update:${data.length}");
  });
  var text = doc.getText("text");
  text.insert(0, "world!");
  print('text2:${doc2.getText("text").toString()}');
  text.insert(0, "hello ");
  print('text2:${doc2.getText("text").toString()}');

}
