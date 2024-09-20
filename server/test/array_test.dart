import 'package:ydart/ydart.dart';
YText createYText() {
  var map = YText("");
  return map;
}

YMap createEmptyTextYMap([YMap? style]) {
  var indent = style?.get("indent");
  var itemType = style?.get("itemType");
  var type = style?.get("type");
  if (type != "quote") {
    type = "text";
  }
  var map = YMap();
  map.set("level", 0);
  map.set("type", type);
  map.set("text", createYText());
  if (indent != null) {
    map.set("indent", indent);
  }
  if (itemType != null) {
    map.set("itemType", itemType);
  }
  return map;
}

YArray createTableRow(int colCount) {
  var arr = YArray();
  arr.insert(0, [for (var i = 0; i < colCount; i++) createEmptyTextYMap()]);
  return arr;
}

YMap createYsTable(int rowCount, int colCount) {
  var table = YMap();
  var rows = YArray();
  rows.insert(0, [for (var i = 0; i < rowCount; i++) createTableRow(colCount)]);
  table.set("type", "table");
  table.set("rows", rows);
  return table;
}

void main() {
  var doc = YDoc();
  var table = createYsTable(4, 3);

  print(table);
  doc.getArray("blocks").insert(0, [table]);
  print((table.get("rows") as YArray).length);
}
