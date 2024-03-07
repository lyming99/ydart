import 'dart:typed_data';

class RelativePosition {
  final int? assoc;
  final int? item;
  final int? typeId;
  final String? tName;

  RelativePosition({this.assoc, this.item, this.typeId, this.tName});

  factory RelativePosition.fromTypeIndex(AbstractType type, int index, {int assoc = 0}) {
    if (assoc < 0) {
      if (index == 0) {
        return RelativePosition(typeId: type.item?.id, assoc: assoc);
      }
      index--;
    }

    var t = type.start;
    while (t != null) {
      if (!t.deleted && t.countable) {
        if (t.length > index) {
          return RelativePosition(typeId: t.id.client, t.id.clock + index, assoc: assoc);
        }
        index -= t.length;
      }

      if (t.right == null && assoc < 0) {
        return RelativePosition(typeId: t.lastId, assoc: assoc);
      }

      t = t.right as Item;
    }

    return RelativePosition(typeId: type.item?.id, assoc: assoc);
  }

  void write(Uint8List writer) {
    if (item != null) {
      writer.writeVarUint(0);
      item.write(writer);
    } else if (tName != null) {
      writer.writeVarUint(1);
      writer.writeVarString(tName);
    } else if (typeId != null) {
      writer.writeVarUint(2);
      typeId.write(writer);
    } else {
      throw Exception();
    }

    writer.writeVarInt(assoc, treatZeroAsNegative: false);
  }

  static RelativePosition read(Uint8List encodedPosition) {
    return read(encodedPosition.buffer.asByteData());
  }

  static RelativePosition read(ByteData reader) {
    int? itemId;
    int? typeId;
    String? tName;

    switch (reader.readVarUint()) {
      case 0:
        itemId = ID.read(reader);
        break;
      case 1:
        tName = reader.readVarString();
        break;
      case 2:
        typeId = ID.read(reader);
        break;
      default:
        throw Exception();
    }

    int assoc = reader.position < reader.length ? reader.readVarInt().value : 0;
    return RelativePosition(typeId: typeId, tName: tName, item: itemId, assoc: assoc);
  }

  Uint8List toArray() {
    final stream = Uint8List();
    write(stream);
    return stream;
  }
}