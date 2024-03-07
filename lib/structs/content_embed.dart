import 'package:ydart/structs/base_content.dart';
import 'package:ydart/utils/encoding.dart';

import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import 'item.dart';

class ContentEmbed extends IContentEx {
  Object embed;

  ContentEmbed(this.embed);

  @override
  int get ref => 5;

  @override
  bool get isCountable => true;

  @override
  int get length => 1;

  @override
  List<Object?> getContent() {
    return [embed];
  }

  @override
  IContent copy() {
    return ContentEmbed(embed);
  }

  @override
  IContent splice(int offset) {
    throw UnimplementedError();
  }

  @override
  bool mergeWith(IContent right) {
    return false;
  }

  @override
  void integrate(Transaction transaction, Item item) {}

  @override
  void delete(Transaction transaction) {}

  @override
  void gc(StructStore store) {}

  @override
  void write(AbstractEncoder encoder, int offset) {
    encoder.writeJson(embed);
  }

  static ContentEmbed read(AbstractDecoder decoder) {
    var content = decoder.readJson();
    return ContentEmbed(content);
  }
}
