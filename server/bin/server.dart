import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alfred/alfred.dart';
import 'package:ydart/utils/y_doc.dart';

void main(List<String> arguments) {
  var app = Alfred();
  app.post("mergeDoc", (req, res) async {
    var params = await req.bodyAsJsonMap;
    var docPath = params['docPath'];
    var update = params['update'] as HttpBodyFileUpload;
    var doc = YDoc();
    if (File(docPath).existsSync()) {
      var docBytes = File(docPath).readAsBytesSync();
      if(docBytes.isNotEmpty) {
        doc.applyUpdateV2(docBytes);
      }
    }
    try {
      var data = Uint8List.fromList(update.content as List<int>);
      doc.applyUpdateV2(data);
      File(docPath).writeAsBytesSync(doc.encodeStateAsUpdateV2());
    } catch (e) {
      print(e);
    }
    return "ok";
  });

  app.post("queryDocState", (req, res) async {
    try {
      var startTime = DateTime.now().millisecondsSinceEpoch;
      var params = await req.bodyAsJsonMap;
      var docPath = params['docPath'];
      if (File(docPath).existsSync()) {
            var doc = YDoc();
            var docBytes = File(docPath).readAsBytesSync();
            doc.applyUpdateV2(docBytes);
            var ret = base64Encode( doc.encodeStateVectorV2());
            print(
                'queryDocState use time: ${DateTime.now().millisecondsSinceEpoch - startTime}');
            return ret;
          }
    } catch (e) {
      print(e);
    }
    return "";
  });

  app.post("queryDocContent", (req, res) async {
    var params = await req.bodyAsJsonMap;
    var docPath = params['docPath'] as String;
    var vector = params['vector'] as String?;
    if (File(docPath).existsSync()) {
      try {
        var doc = YDoc();
        var docBytes = File(docPath).readAsBytesSync();
        doc.applyUpdateV2(docBytes);
        if (vector != null) {
                var vectorBytes = base64Decode(vector);
                return doc.encodeStateAsUpdateV2(vectorBytes);
              }
        return doc.encodeStateAsUpdateV2();
      } catch (e) {
        print(e);
      }
    }
    return Uint8List(0);
  });
  app.listen(3653);
}
