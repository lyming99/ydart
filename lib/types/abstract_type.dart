import 'package:ydart/utils/encoding.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/transaction.dart';
import 'package:ydart/utils/y_doc.dart';
import 'package:ydart/utils/y_event.dart';

import '../structs/item.dart';

typedef EventHandler<T> = Function(Object object, T callback);

class YEventArgs {
  YEvent event;
  Transaction transaction;

  YEventArgs({
    required this.event,
    required this.transaction,
  });
}

class YDeepEventArgs {
  List<YEvent> events;
  Transaction transaction;

  YDeepEventArgs({
    required this.events,
    required this.transaction,
  });
}

class AbstractType {
  Item? item;
  Item? start;
  Map<String, Item> map = {};
  EventHandler<YEventArgs>? eventHandler;
  EventHandler<YDeepEventArgs>? deepEventHandler;
  YDoc? doc;
  int length = 0;

  AbstractType? get parent {
    var parent = item?.parent;
    if (parent is AbstractType) {
      return parent;
    }
    return null;
  }

  void integrate(YDoc? doc, Item item) {}

  AbstractType internalCopy() {
    throw UnimplementedError();
  }

  AbstractType internalClone() {
    throw UnimplementedError();
  }

  void write(AbstractEncoder encoder) {}

  void callTypeObservers(Transaction transaction, YEvent event) {}

  void callObserver(Transaction transaction, Set<String> parentSubs) {}

  Item first() {
    throw UnimplementedError();
  }

  void invokeEventHandlers(YEvent event, Transaction transaction) {
    eventHandler?.call(
        this, YEventArgs(event: event, transaction: transaction));
  }

  void callDeepEventHandlerListeners(
      List<YEvent> events, Transaction transaction) {
    deepEventHandler?.call(
        this, YDeepEventArgs(events: events, transaction: transaction));
  }

  String findRootTypeKey() {
    return doc!.findRootTypeKey(this);
  }

  void typeMapDelete(Transaction transaction, String key) {
    throw UnimplementedError();
  }

  void typeMapSet(Transaction transaction, String key, Object value) {
    throw UnimplementedError();
  }

  Object? tryTypeMapGet(String key) {
    throw UnimplementedError();
  }

  Object typeMapGetSnapshot(String key, Snapshot snapshot) {
    throw UnimplementedError();
  }

}
