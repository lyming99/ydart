import 'dart:math';
import 'dart:typed_data';

class YDocOptions {
  static bool DefaultPredicate(Item item) => true;

  bool gc = true;
  Predicate<Item> gcFilter = DefaultPredicate;
  String guid = Uuid().v4();
  Map<String, String>? meta;
  bool autoLoad = false;

  YDocOptions clone() {
    return YDocOptions()
      ..gc = gc
      ..gcFilter = gcFilter
      ..guid = guid
      ..meta = meta != null ? Map<String, String>.from(meta!) : null
      ..autoLoad = autoLoad;
  }

  void write(IUpdateEncoder encoder, int offset) {
    var dict = <String, dynamic>{
      'gc': gc,
      'guid': guid,
      'autoLoad': autoLoad,
    };

    if (meta != null) {
      dict['meta'] = meta;
    }

    encoder.writeAny(dict);
  }

  static YDocOptions read(IUpdateDecoder decoder) {
    var dict = decoder.readAny() as Map<String, dynamic>;

    var result = YDocOptions();
    result.gc = dict.containsKey('gc') ? dict['gc'] as bool : true;
    result.guid = dict.containsKey('guid') ? dict['guid'].toString() : Uuid().v4();
    result.meta = dict.containsKey('meta') ? dict['meta'] as Map<String, String> : null;
    result.autoLoad = dict.containsKey('autoLoad') ? dict['autoLoad'] as bool : false;

    return result;
  }
}

class YDoc {
  final YDocOptions _opts;
  late int clientId;
  final Map<String, AbstractType> _share = {};

  YDoc(YDocOptions? opts)
      : _opts = opts ?? YDocOptions(),
        _transactionCleanups = [],
        clientId = _generateNewClientId(),
        _share = {},
        store = StructStore(),
        subdocs = {},
        shouldLoad = _opts.autoLoad;

  static int _generateNewClientId() {
    return Random().nextInt(0x7FFFFFFF);
  }

  void transact(void Function(Transaction) fun, {Object? origin, bool local = true}) {
    var initialCall = false;
    if (_transaction == null) {
      initialCall = true;
      _transaction = Transaction(this, origin, local);
      _transactionCleanups.add(_transaction!);
      if (_transactionCleanups.length == 1) {
        _invokeBeforeAllTransactions();
      }

      _invokeOnBeforeTransaction(_transaction!);
    }

    try {
      fun(_transaction!);
    } finally {
      if (initialCall && _transactionCleanups[0] == _transaction) {
        Transaction.cleanupTransactions(_transactionCleanups, 0);
      }
    }
  }

  YArray getArray([String name = '']) {
    return get<YArray>(name);
  }

  YMap getMap([String name = '']) {
    return get<YMap>(name);
  }

  YText getText([String name = '']) {
    return get<YText>(name);
  }

  T get<T extends AbstractType>(String name) {
    if (!_share.containsKey(name)) {
      var type = T();
      type.integrate(this, null);
      _share[name] = type;
    }

    if (T != AbstractType && !T.isAssignableFrom(_share[name]!.runtimeType)) {
      if (_share[name]!.runtimeType == AbstractType) {
        var t = T();
        t._map = _share[name]!._map;

        for (var kvp in _share[name]!._map.entries) {
          var n = kvp.value;
          for (; n != null; n = n.left as Item) {
            n.parent = t;
          }
        }

        t._start = _share[name]!._start;
        for (var n = t._start; n != null; n = n.right as Item) {
          n.parent = t;
        }

        t.length = _share[name]!.length;

        _share[name] = t;
        t.integrate(this, null);
        return t;
      } else {
        throw Exception('Type with the name $name has already been defined with a different constructor');
      }
    }

    return _share[name] as T;
  }

  void applyUpdateV2(Stream input, {Object? transactionOrigin, bool local = false}) {
    transact((tr) {
      var structDecoder = UpdateDecoderV2(input);
      EncodingUtils.readStructs(structDecoder, tr, store);
      store.readAndApplyDeleteSet(structDecoder, tr);
    }, origin: transactionOrigin, local: local);
  }

  void applyUpdateV2(Uint8List update, {Object? transactionOrigin, bool local = false}) {
    applyUpdateV2(update, transactionOrigin: transactionOrigin, local: local);
  }

  Uint8List encodeStateAsUpdateV2([Uint8List? encodedTargetStateVector]) {
    var targetStateVector = encodedTargetStateVector != null
        ? EncodingUtils.decodeStateVector(encodedTargetStateVector)
        : <int, int>{};
    var encoder = UpdateEncoderV2();
    writeStateAsUpdate(encoder, targetStateVector);
    return encoder.toUint8List();
  }

  Uint8List encodeStateVectorV2() {
    var encoder = DSEncoderV2();
    writeStateVector(encoder);
    return encoder.toUint8List();
  }

  void writeStateAsUpdate(IUpdateEncoder encoder, Map<int, int> targetStateVector) {
    EncodingUtils.writeClientsStructs(encoder, store, targetStateVector);
    DeleteSet(store).write(encoder);
  }

  void writeStateVector(IDSEncoder encoder) {
    EncodingUtils.writeStateVector(encoder, store.getStateVector());
  }

  void invokeSubdocsChanged(Set<YDoc> loaded, Set<YDoc> added, Set<YDoc> removed) {
    subdocsChanged?.call(this, (loaded, added, removed));
  }

  void invokeOnBeforeObserverCalls(Transaction transaction) {
    beforeObserverCalls?.call(this, transaction);
  }

  void invokeAfterAllTransactions(List<Transaction> transactions) {
    afterAllTransactions?.call(this, transactions);
  }

  void invokeOnBeforeTransaction(Transaction transaction) {
    beforeTransaction?.call(this, transaction);
  }

  void invokeOnAfterTransaction(Transaction transaction) {
    afterTransaction?.call(this, transaction);
  }

  void invokeOnAfterTransactionCleanup(Transaction transaction) {
    afterTransactionCleanup?.call(this, transaction);
  }

  void invokeBeforeAllTransactions() {
    beforeAllTransactions?.call(this, null);
  }

  void invokeDestroyed() {
    destroyed?.call(this, null);
  }

  void invokeUpdateV2(Transaction transaction) {
    var handler = updateV2;
    if (handler != null) {
      var encoder = UpdateEncoderV2();
      var hasContent = transaction.writeUpdateMessageFromTransaction(encoder);
      if (hasContent) {
        handler(this, (encoder.toUint8List(), transaction.origin, transaction));
      }
    }
  }

  YDocOptions cloneOptionsWithNewGuid() {
    var newOpts = _opts.clone();
    newOpts.guid = Uuid().v4();
    return newOpts;
  }

  String findRootTypeKey(AbstractType type) {
    for (var kvp in _share.entries) {
      if (type == kvp.value) {
        return kvp.key;
      }
    }

    throw Exception();
  }
}