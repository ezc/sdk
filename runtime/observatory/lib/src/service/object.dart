// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of service;

/// An RpcException represents an exceptional event that happened
/// while invoking an rpc.
abstract class RpcException implements Exception {
  RpcException(this.message);

  String message;
}

/// A ServerRpcException represents an error returned by the VM.
class ServerRpcException extends RpcException {
  /// A list of well-known server error codes.
  static const kParseError     = -32700;
  static const kInvalidRequest = -32600;
  static const kMethodNotFound = -32601;
  static const kInvalidParams  = -32602;
  static const kInternalError  = -32603;
  static const kFeatureDisabled         = 100;
  static const kVMMustBePaused          = 101;
  static const kCannotAddBreakpoint     = 102;
  static const kStreamAlreadySubscribed = 103;
  static const kStreamNotSubscribed     = 104;

  int code;
  Map data;

  static _getMessage(Map errorMap) {
    Map data = errorMap['data'];
    if (data != null && data['details'] != null) {
      return data['details'];
    } else {
      return errorMap['message'];
    }
  }

  ServerRpcException.fromMap(Map errorMap) : super(_getMessage(errorMap)) {
    code = errorMap['code'];
    data = errorMap['data'];
  }

  String toString() => 'ServerRpcException(${message})';
}

/// A NetworkRpcException is used to indicate that an rpc has
/// been canceled due to network error.
class NetworkRpcException extends RpcException {
  NetworkRpcException(String message) : super(message);

  String toString() => 'NetworkRpcException(${message})';
}

class MalformedResponseRpcException extends RpcException {
  MalformedResponseRpcException(String message, this.response)
      : super(message);

  Map response;

  String toString() => 'MalformedResponseRpcException(${message})';
}

class FakeVMRpcException extends RpcException {
  FakeVMRpcException(String message) : super(message);

  String toString() => 'FakeVMRpcException(${message})';
}

/// A [ServiceObject] represents a persistent object within the vm.
abstract class ServiceObject extends Observable {
  static int LexicalSortName(ServiceObject o1, ServiceObject o2) {
    return o1.name.compareTo(o2.name);
  }

  List removeDuplicatesAndSortLexical(List<ServiceObject> list) {
    return list.toSet().toList()..sort(LexicalSortName);
  }

  /// The owner of this [ServiceObject].  This can be an [Isolate], a
  /// [VM], or null.
  @reflectable ServiceObjectOwner get owner => _owner;
  ServiceObjectOwner _owner;

  /// The [VM] which owns this [ServiceObject].
  @reflectable VM get vm => _owner.vm;

  /// The [Isolate] which owns this [ServiceObject].  May be null.
  @reflectable Isolate get isolate => _owner.isolate;

  /// The id of this object.
  @reflectable String get id => _id;
  String _id;

  /// The user-level type of this object.
  @reflectable String get type => _type;
  String _type;

  /// The vm type of this object.
  @reflectable String get vmType => _vmType;
  String _vmType;

  bool get isContext => type == 'Context';
  bool get isError => type == 'Error';
  bool get isInstance => type == 'Instance';
  bool get isSentinel => type == 'Sentinel';
  bool get isMessage => type == 'Message';

  // Kinds of Instance.
  bool get isAbstractType => false;
  bool get isNull => false;
  bool get isBool => false;
  bool get isDouble => false;
  bool get isString => false;
  bool get isInt => false;
  bool get isList => false;
  bool get isMap => false;
  bool get isTypedData => false;
  bool get isMirrorReference => false;
  bool get isWeakProperty => false;
  bool get isClosure => false;
  bool get isPlainInstance => false;

  /// Has this object been fully loaded?
  bool get loaded => _loaded;
  bool _loaded = false;
  // TODO(turnidge): Make loaded observable and get rid of loading
  // from Isolate.

  /// Is this object cacheable?  That is, is it impossible for the [id]
  /// of this object to change?
  bool _canCache;
  bool get canCache => _canCache;

  /// Is this object immutable after it is [loaded]?
  bool get immutable => false;

  @observable String name;
  @observable String vmName;

  /// Creates an empty [ServiceObject].
  ServiceObject._empty(this._owner);

  /// Creates a [ServiceObject] initialized from [map].
  factory ServiceObject._fromMap(ServiceObjectOwner owner,
                                 ObservableMap map) {
    if (map == null) {
      return null;
    }
    if (!_isServiceMap(map)) {
      Logger.root.severe('Malformed service object: $map');
    }
    assert(_isServiceMap(map));
    var type = _stripRef(map['type']);
    var vmType = map['_vmType'] != null ? map['_vmType'] : type;
    var obj = null;
    assert(type != 'VM');
    switch (type) {
      case 'Breakpoint':
        obj = new Breakpoint._empty(owner);
        break;
      case 'Class':
        obj = new Class._empty(owner);
        break;
      case 'Code':
        obj = new Code._empty(owner);
        break;
      case 'Context':
        obj = new Context._empty(owner);
        break;
      case 'Counter':
        obj = new ServiceMetric._empty(owner);
        break;
      case 'Error':
        obj = new DartError._empty(owner);
        break;
      case 'Field':
        obj = new Field._empty(owner);
        break;
      case 'Frame':
        obj = new Frame._empty(owner);
        break;
      case 'Function':
        obj = new ServiceFunction._empty(owner);
        break;
      case 'Gauge':
        obj = new ServiceMetric._empty(owner);
        break;
      case 'Isolate':
        obj = new Isolate._empty(owner.vm);
        break;
      case 'Library':
        obj = new Library._empty(owner);
        break;
      case 'Message':
        obj = new ServiceMessage._empty(owner);
        break;
      case 'SourceLocation':
        obj = new SourceLocation._empty(owner);
        break;
      case 'Object':
        switch (vmType) {
          case 'PcDescriptors':
            obj = new PcDescriptors._empty(owner);
            break;
          case 'LocalVarDescriptors':
            obj = new LocalVarDescriptors._empty(owner);
            break;
          case 'TokenStream':
            obj = new TokenStream._empty(owner);
            break;
        }
        break;
      case 'Event':
        obj = new ServiceEvent._empty(owner);
        break;
      case 'Script':
        obj = new Script._empty(owner);
        break;
      case 'Socket':
        obj = new Socket._empty(owner);
        break;
      case 'Instance':
      case 'Sentinel':  // TODO(rmacnak): Separate this out.
        obj = new Instance._empty(owner);
        break;
      default:
        break;
    }
    if (obj == null) {
      obj = new ServiceMap._empty(owner);
    }
    obj.update(map);
    return obj;
  }

  /// If [this] was created from a reference, load the full object
  /// from the service by calling [reload]. Else, return [this].
  Future<ServiceObject> load() {
    if (loaded) {
      return new Future.value(this);
    }
    // Call reload which will fill in the entire object.
    return reload();
  }

  Future<ServiceObject> _inProgressReload;

  Future<ObservableMap> _fetchDirect() {
    Map params = {
      'objectId': id,
    };
    return isolate.invokeRpcNoUpgrade('getObject', params);
  }

  /// Reload [this]. Returns a future which completes to [this] or
  /// an exception.
  Future<ServiceObject> reload() {
    // TODO(turnidge): Checking for a null id should be part of the
    // "immmutable" check.
    bool hasId = (id != null) && (id != '');
    bool isVM = this is VM;
    // We should always reload the VM.
    // We can't reload objects without an id.
    // We shouldn't reload an immutable and already loaded object.
    bool skipLoad = !isVM && (!hasId || (immutable && loaded));
    if (skipLoad) {
      return new Future.value(this);
    }
    if (_inProgressReload == null) {
      var completer = new Completer<ServiceObject>();
      _inProgressReload = completer.future;
      _fetchDirect().then((ObservableMap map) {
        var mapType = _stripRef(map['type']);
        if (mapType == 'Sentinel') {
          // An object may have been collected, etc.
          completer.complete(new ServiceObject._fromMap(owner, map));
        } else {
          // TODO(turnidge): Check for vmType changing as well?
          assert(mapType == _type);
          update(map);
          completer.complete(this);
        }

      }).catchError((e, st) {
        Logger.root.severe("Unable to reload object: $e\n$st");
        _inProgressReload = null;
        completer.completeError(e, st);
      }).whenComplete(() {
        // This reload is complete.
        _inProgressReload = null;
      });
    }
    return _inProgressReload;
  }

  /// Update [this] using [map] as a source. [map] can be a reference.
  void update(ObservableMap map) {
    assert(_isServiceMap(map));

    // Don't allow the type to change on an object update.
    var mapIsRef = _hasRef(map['type']);
    var mapType = _stripRef(map['type']);
    assert(_type == null || _type == mapType);

    _canCache = map['fixedId'] == true;
    if (_id != null && _id != map['id']) {
      // It is only safe to change an id when the object isn't cacheable.
      assert(!canCache);
    }
    _id = map['id'];

    _type = mapType;

    // When the response specifies a specific vmType, use it.
    // Otherwise the vmType of the response is the same as the 'user'
    // type.
    if (map.containsKey('_vmType')) {
      _vmType = _stripRef(map['_vmType']);
    } else {
      _vmType = _type;
    }

    _update(map, mapIsRef);
  }

  // Updates internal state from [map]. [map] can be a reference.
  void _update(ObservableMap map, bool mapIsRef);

  // Helper that can be passed to .catchError that ignores the error.
  _ignoreError(error, stackTrace) {
    // do nothing.
  }
}

abstract class Coverage {
  // Following getters and functions will be provided by [ServiceObject].
  String get id;
  Isolate get isolate;

  Future refreshCoverage() {
    return refreshCallSiteData();
  }

  /// Default handler for coverage data.
  void processCallSiteData(List coverageData) {
    coverageData.forEach((scriptCoverage) {
      assert(scriptCoverage['script'] != null);
      scriptCoverage['script']._processCallSites(scriptCoverage['callSites']);
    });
  }

  Future refreshCallSiteData() {
    Map params = {};
    if (this is! Isolate) {
      params['targetId'] = id;
    }
    return isolate.invokeRpcNoUpgrade('_getCallSiteData', params).then(
        (ObservableMap map) {
          var coverage = new ServiceObject._fromMap(isolate, map);
          assert(coverage.type == 'CodeCoverage');
          var coverageList = coverage['coverage'];
          assert(coverageList != null);
          processCallSiteData(coverageList);
          return this;
        });
  }
}

abstract class ServiceObjectOwner extends ServiceObject {
  /// Creates an empty [ServiceObjectOwner].
  ServiceObjectOwner._empty(ServiceObjectOwner owner) : super._empty(owner);

  /// Builds a [ServiceObject] corresponding to the [id] from [map].
  /// The result may come from the cache.  The result will not necessarily
  /// be [loaded].
  ServiceObject getFromMap(ObservableMap map);
}

/// A [SourceLocation] represents a location or range in the source code.
class SourceLocation extends ServiceObject {
  Script script;
  int tokenPos;
  int endTokenPos;

  SourceLocation._empty(ServiceObject owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    assert(!mapIsRef);
    _upgradeCollection(map, owner);
    script = map['script'];
    tokenPos = map['tokenPos'];
    assert(script != null && tokenPos != null);
    endTokenPos = map['endTokenPos'];
  }

  String toString() {
    if (endTokenPos == null) {
      return '${script.name}:token(${tokenPos})';
    } else {
      return '${script.name}:tokens(${tokenPos}-${endTokenPos})';
    }
  }
}

/// State for a VM being inspected.
abstract class VM extends ServiceObjectOwner {
  @reflectable VM get vm => this;
  @reflectable Isolate get isolate => null;

  // TODO(turnidge): The connection should not be stored in the VM object.
  bool get isDisconnected;

  // TODO(johnmccutchan): Ensure that isolates do not end up in _cache.
  Map<String,ServiceObject> _cache = new Map<String,ServiceObject>();
  final ObservableMap<String,Isolate> _isolateCache =
      new ObservableMap<String,Isolate>();

  @reflectable Iterable<Isolate> get isolates => _isolateCache.values;

  @observable String version = 'unknown';
  @observable String targetCPU;
  @observable int architectureBits;
  @observable bool assertsEnabled = false;
  @observable bool typeChecksEnabled = false;
  @observable String pid = '';
  @observable DateTime startTime;
  @observable DateTime refreshTime;
  @observable Duration get upTime =>
      (new DateTime.now().difference(startTime));

  VM() : super._empty(null) {
    name = 'vm';
    vmName = 'vm';
    _cache['vm'] = this;
    update(toObservable({'id':'vm', 'type':'@VM'}));
  }

  final StreamController<ServiceEvent> events =
      new StreamController.broadcast();

  void postServiceEvent(Map response, ByteData data) {
    var map = toObservable(response);
    assert(!map.containsKey('_data'));
    if (data != null) {
      map['_data'] = data;
    }
    if (map['type'] != 'Event') {
      Logger.root.severe(
          "Expected 'Event' but found '${map['type']}'");
      return;
    }

    var eventIsolate = map['isolate'];
    if (eventIsolate == null) {
      var event = new ServiceObject._fromMap(vm, map);
      events.add(event);
    } else {
      // getFromMap creates the Isolate if it hasn't been seen already.
      var isolate = getFromMap(map['isolate']);
      var event = new ServiceObject._fromMap(isolate, map);
      if (event.kind == ServiceEvent.kIsolateExit) {
        _removeIsolate(isolate.id);
      }
      isolate._onEvent(event);
      events.add(event);
    }
  }

  void _removeIsolate(String isolateId) {
    assert(_isolateCache.containsKey(isolateId));
    _isolateCache.remove(isolateId);
    notifyPropertyChange(#isolates, true, false);
  }

  void _removeDeadIsolates(List newIsolates) {
    // Build a set of new isolates.
    var newIsolateSet = new Set();
    newIsolates.forEach((iso) => newIsolateSet.add(iso.id));

    // Remove any old isolates which no longer exist.
    List toRemove = [];
    _isolateCache.forEach((id, _) {
      if (!newIsolateSet.contains(id)) {
        toRemove.add(id);
      }
    });
    toRemove.forEach((id) => _removeIsolate(id));
    notifyPropertyChange(#isolates, true, false);
  }

  static final String _isolateIdPrefix = 'isolates/';

  ServiceObject getFromMap(ObservableMap map) {
    if (map == null) {
      return null;
    }
    String id = map['id'];
    if (!id.startsWith(_isolateIdPrefix)) {
      // Currently the VM only supports upgrading Isolate ServiceObjects.
      throw new UnimplementedError();
    }

    // Check cache.
    var isolate = _isolateCache[id];
    if (isolate == null) {
      // Add new isolate to the cache.
      isolate = new ServiceObject._fromMap(this, map);
      _isolateCache[id] = isolate;
      notifyPropertyChange(#isolates, true, false);

      // Eagerly load the isolate.
      isolate.load().catchError((e, stack) {
        Logger.root.info('Eagerly loading an isolate failed: $e\n$stack');
      });
    } else {
      isolate.update(map);
    }
    return isolate;
  }

  // Note that this function does not reload the isolate if it found
  // in the cache.
  Future<ServiceObject> getIsolate(String isolateId) {
    if (!loaded) {
      // Trigger a VM load, then get the isolate.
      return load().then((_) => getIsolate(isolateId)).catchError(_ignoreError);
    }
    return new Future.value(_isolateCache[isolateId]);
  }

  // Implemented in subclass.
  Future<Map> invokeRpcRaw(String method, Map params);

  Future<ObservableMap> invokeRpcNoUpgrade(String method, Map params) {
    return invokeRpcRaw(method, params).then((Map response) {
      var map = toObservable(response);
      if (Tracer.current != null) {
        Tracer.current.trace("Received response for ${method}/${params}}",
                             map:map);
      }
      if (!_isServiceMap(map)) {
        var exception =
            new MalformedResponseRpcException(
                "Response is missing the 'type' field", map);
        return new Future.error(exception);
      }
      return new Future.value(map);
    }).catchError((e) {
      // Errors pass through.
      return new Future.error(e);
    });
  }

  Future<ServiceObject> invokeRpc(String method, Map params) {
    return invokeRpcNoUpgrade(method, params).then((ObservableMap response) {
      var obj = new ServiceObject._fromMap(this, response);
      if ((obj != null) && obj.canCache) {
        String objId = obj.id;
        _cache.putIfAbsent(objId, () => obj);
      }
      return obj;
    });
  }

  Future<ObservableMap> _fetchDirect() async {
    if (!loaded) {
      // TODO(turnidge): Instead of always listening to all streams,
      // implement a stream abstraction in the service library so
      // that we only subscribe to the streams we want.
      await _streamListen('Isolate');
      await _streamListen('Debug');
      await _streamListen('GC');
      await _streamListen('_Echo');
      await _streamListen('_Graph');
    }
    return await invokeRpcNoUpgrade('getVM', {});
  }

  Future<ServiceObject> getFlagList() {
    return invokeRpc('getFlagList', {});
  }

  Future<ServiceObject> _streamListen(String streamId) {
    Map params = {
      'streamId': streamId,
    };
    return invokeRpc('streamListen', params);
  }

  /// Force the VM to disconnect.
  void disconnect();
  /// Completes when the VM first connects.
  Future get onConnect;
  /// Completes when the VM disconnects or there was an error connecting.
  Future get onDisconnect;

  void _update(ObservableMap map, bool mapIsRef) {
    if (mapIsRef) {
      return;
    }
    // Note that upgrading the collection creates any isolates in the
    // isolate list which are new.
    _upgradeCollection(map, vm);

    _loaded = true;
    version = map['version'];
    targetCPU = map['targetCPU'];
    architectureBits = map['architectureBits'];
    var startTimeMillis = map['startTime'];
    startTime = new DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
    refreshTime = new DateTime.now();
    notifyPropertyChange(#upTime, 0, 1);
    pid = map['pid'];
    assertsEnabled = map['_assertsEnabled'];
    typeChecksEnabled = map['_typeChecksEnabled'];
    _removeDeadIsolates(map['isolates']);
  }

  // Reload all isolates.
  Future reloadIsolates() {
    var reloads = [];
    for (var isolate in isolates) {
      var reload = isolate.reload().catchError((e) {
        Logger.root.info('Bulk reloading of isolates failed: $e');
      });
      reloads.add(reload);
    }
    return Future.wait(reloads);
  }
}

class FakeVM extends VM {
  final Map _responses = {};
  FakeVM(Map responses) {
    if (responses == null) {
      return;
    }
    responses.forEach((uri, response) {
      // Encode as string.
      _responses[_canonicalizeUri(Uri.parse(uri))] = response;
    });
  }

  String _canonicalizeUri(Uri uri) {
    // We use the uri as the key to the response map. Uri parameters can be
    // serialized in any order, this function canonicalizes the uri parameters
    // so they are serialized in sorted-by-parameter-name order.
    var method = uri.path;
    // Create a map sorted on insertion order.
    var parameters = new Map();
    // Sort keys.
    var sortedKeys = uri.queryParameters.keys.toList();
    sortedKeys.sort();
    // Filter keys to remove any private options.
    sortedKeys.removeWhere((k) => k.startsWith('_'));
    // Insert parameters in sorted order.
    for (var key in sortedKeys) {
      parameters[key] = uri.queryParameters[key];
    }
    // Return canonical uri.
    return new Uri(path: method, queryParameters: parameters).toString();
  }

  /// Force the VM to disconnect.
  void disconnect() {
    _onDisconnect.complete(this);
  }

  // Always connected.
  Future _onConnect;
  Future get onConnect {
    if (_onConnect != null) {
      return _onConnect;
    }
    _onConnect = new Future.value(this);
    return _onConnect;
  }
  // Only complete when requested.
  Completer _onDisconnect = new Completer();
  Future get onDisconnect => _onDisconnect.future;
  bool get isDisconnected => _onDisconnect.isCompleted;

  Future<Map> invokeRpcRaw(String method, Map params) {
    if (params.isEmpty) {
      params = null;
    }
    var key = _canonicalizeUri(new Uri(path: method, queryParameters: params));
    var response = _responses[key];
    if (response == null) {
      return new Future.error(new FakeVMRpcException(
          "Unable to find key '${key}' in cached response set"));
    }
    return new Future.value(response);
  }
}


/// Snapshot in time of tag counters.
class TagProfileSnapshot {
  final double seconds;
  final List<int> counters;
  int get sum => _sum;
  int _sum = 0;
  TagProfileSnapshot(this.seconds, int countersLength)
      : counters = new List<int>(countersLength);

  /// Set [counters] and update [sum].
  void set(List<int> counters) {
    this.counters.setAll(0, counters);
    for (var i = 0; i < this.counters.length; i++) {
      _sum += this.counters[i];
    }
  }

  /// Set [counters] with the delta from [counters] to [old_counters]
  /// and update [sum].
  void delta(List<int> counters, List<int> old_counters) {
    for (var i = 0; i < this.counters.length; i++) {
      this.counters[i] = counters[i] - old_counters[i];
      _sum += this.counters[i];
    }
  }

  /// Update [counters] with new maximum values seen in [counters].
  void max(List<int> counters) {
    for (var i = 0; i < counters.length; i++) {
      var c = counters[i];
      this.counters[i] = this.counters[i] > c ? this.counters[i] : c;
    }
  }

  /// Zero [counters].
  void zero() {
    for (var i = 0; i < counters.length; i++) {
      counters[i] = 0;
    }
  }
}

class TagProfile {
  final List<String> names = new List<String>();
  final List<TagProfileSnapshot> snapshots = new List<TagProfileSnapshot>();
  double get updatedAtSeconds => _seconds;
  double _seconds;
  TagProfileSnapshot _maxSnapshot;
  int _historySize;
  int _countersLength = 0;

  TagProfile(this._historySize);

  void _processTagProfile(double seconds, ObservableMap tagProfile) {
    _seconds = seconds;
    var counters = tagProfile['counters'];
    if (names.length == 0) {
      // Initialization.
      names.addAll(tagProfile['names']);
      _countersLength = tagProfile['counters'].length;
      for (var i = 0; i < _historySize; i++) {
        var snapshot = new TagProfileSnapshot(0.0, _countersLength);
        snapshot.zero();
        snapshots.add(snapshot);
      }
      // The counters monotonically grow, keep track of the maximum value.
      _maxSnapshot = new TagProfileSnapshot(0.0, _countersLength);
      _maxSnapshot.set(counters);
      return;
    }
    var snapshot = new TagProfileSnapshot(seconds, _countersLength);
    // We snapshot the delta from the current counters to the maximum counter
    // values.
    snapshot.delta(counters, _maxSnapshot.counters);
    _maxSnapshot.max(counters);
    snapshots.add(snapshot);
    // Only keep _historySize snapshots.
    if (snapshots.length > _historySize) {
      snapshots.removeAt(0);
    }
  }
}

class HeapSpace extends Observable {
  @observable int used = 0;
  @observable int capacity = 0;
  @observable int external = 0;
  @observable int collections = 0;
  @observable double totalCollectionTimeInSeconds = 0.0;
  @observable double averageCollectionPeriodInMillis = 0.0;

  void update(Map heapMap) {
    used = heapMap['used'];
    capacity = heapMap['capacity'];
    external = heapMap['external'];
    collections = heapMap['collections'];
    totalCollectionTimeInSeconds = heapMap['time'];
    averageCollectionPeriodInMillis = heapMap['avgCollectionPeriodMillis'];
  }
}

class HeapSnapshot {
  final ObjectGraph graph;
  final DateTime timeStamp;
  final Isolate isolate;

  HeapSnapshot(this.isolate, chunks, nodeCount) :
      graph = new ObjectGraph(chunks, nodeCount),
      timeStamp = new DateTime.now();

  List<Future<ServiceObject>> getMostRetained({int classId, int limit}) {
    var result = [];
    for (ObjectVertex v in graph.getMostRetained(classId: classId,
                                                 limit: limit)) {
      result.add(isolate.getObjectByAddress(v.address.toRadixString(16))
                        .then((ServiceObject obj) {
        if (obj is Instance) {
          // TODO(rmacnak): size/retainedSize are properties of all heap
          // objects, not just Instances.
          obj.retainedSize = v.retainedSize;
        }
        return obj;
      }));
    }
    return result;
  }
}

/// State for a running isolate.
class Isolate extends ServiceObjectOwner with Coverage {
  @reflectable VM get vm => owner;
  @reflectable Isolate get isolate => this;
  @observable int number;
  @observable DateTime startTime;
  @observable Duration get upTime =>
      (new DateTime.now().difference(startTime));

  @observable ObservableMap counters = new ObservableMap();

  void _updateRunState() {
    topFrame = (pauseEvent != null ? pauseEvent.topFrame : null);
    paused = (pauseEvent != null &&
              pauseEvent.kind != ServiceEvent.kResume);
    running = (!paused && topFrame != null);
    idle = (!paused && topFrame == null);
    notifyPropertyChange(#topFrame, 0, 1);
    notifyPropertyChange(#paused, 0, 1);
    notifyPropertyChange(#running, 0, 1);
    notifyPropertyChange(#idle, 0, 1);
  }

  @observable ServiceEvent pauseEvent = null;
  @observable bool paused = false;
  @observable bool running = false;
  @observable bool idle = false;
  @observable bool loading = true;

  @observable bool ioEnabled = false;

  Map<String,ServiceObject> _cache = new Map<String,ServiceObject>();
  final TagProfile tagProfile = new TagProfile(20);

  Isolate._empty(ServiceObjectOwner owner) : super._empty(owner) {
    assert(owner is VM);
  }

  void resetCachedProfileData() {
    _cache.values.forEach((value) {
      if (value is Code) {
        Code code = value;
        code.profile = null;
      } else if (value is ServiceFunction) {
        ServiceFunction function = value;
        function.profile = null;
      }
    });
  }

  /// Fetches and builds the class hierarchy for this isolate. Returns the
  /// Object class object.
  Future<Class> getClassHierarchy() {
    return invokeRpc('getClassList', {})
        .then(_loadClasses)
        .then(_buildClassHierarchy);
  }

  Future<ServiceObject> getPorts() {
    return invokeRpc('_getPorts', {});
  }

  Future<List<Class>> getClassRefs() async {
    ServiceMap classList = await invokeRpc('getClassList', {});
    assert(classList.type == 'ClassList');
    var classRefs = [];
    for (var cls in classList['classes']) {
      // Skip over non-class classes.
      if (cls is Class) {
        _classesByCid[cls.vmCid] = cls;
        classRefs.add(cls);
      }
    }
    return classRefs;
  }

  /// Given the class list, loads each class.
  Future<List<Class>> _loadClasses(ServiceMap classList) {
    assert(classList.type == 'ClassList');
    var futureClasses = [];
    for (var cls in classList['classes']) {
      // Skip over non-class classes.
      if (cls is Class) {
        _classesByCid[cls.vmCid] = cls;
        futureClasses.add(cls.load());
      }
    }
    return Future.wait(futureClasses);
  }

  /// Builds the class hierarchy and returns the Object class.
  Future<Class> _buildClassHierarchy(List<Class> classes) {
    rootClasses.clear();
    objectClass = null;
    for (var cls in classes) {
      if (cls.superclass == null) {
        rootClasses.add(cls);
      }
      if ((cls.vmName == 'Object') && (cls.isPatch == false)) {
        objectClass = cls;
      }
    }
    assert(objectClass != null);
    return new Future.value(objectClass);
  }

  Class getClassByCid(int cid) => _classesByCid[cid];

  ServiceObject getFromMap(ObservableMap map) {
    if (map == null) {
      return null;
    }
    var mapType = _stripRef(map['type']);
    if (mapType == 'Isolate') {
      // There are sometimes isolate refs in ServiceEvents.
      return vm.getFromMap(map);
    }
    String mapId = map['id'];
    var obj = (mapId != null) ? _cache[mapId] : null;
    if (obj != null) {
      obj.update(map);
      return obj;
    }
    // Build the object from the map directly.
    obj = new ServiceObject._fromMap(this, map);
    if ((obj != null) && obj.canCache) {
      _cache[mapId] = obj;
    }
    return obj;
  }

  Future<ObservableMap> invokeRpcNoUpgrade(String method, Map params) {
    params['isolateId'] = id;
    return vm.invokeRpcNoUpgrade(method, params);
  }

  Future<ServiceObject> invokeRpc(String method, Map params) {
    return invokeRpcNoUpgrade(method, params).then((ObservableMap response) {
      return getFromMap(response);
    });
  }

  Future<ServiceObject> getObject(String objectId) {
    assert(objectId != null && objectId != '');
    var obj = _cache[objectId];
    if (obj != null) {
      return obj.reload();
    }
    Map params = {
      'objectId': objectId,
    };
    return isolate.invokeRpc('getObject', params);
  }

  Future<ObservableMap> _fetchDirect() {
    return invokeRpcNoUpgrade('getIsolate', {});
  }

  @observable Class objectClass;
  @observable final rootClasses = new ObservableList<Class>();
  Map<int, Class> _classesByCid = new Map<int, Class>();

  @observable Library rootLibrary;
  @observable ObservableList<Library> libraries =
      new ObservableList<Library>();
  @observable Frame topFrame;

  @observable String name;
  @observable String vmName;
  @observable ServiceFunction entry;

  @observable final Map<String, double> timers =
      toObservable(new Map<String, double>());

  final HeapSpace newSpace = new HeapSpace();
  final HeapSpace oldSpace = new HeapSpace();

  @observable String fileAndLine;

  @observable DartError error;
  @observable HeapSnapshot latestSnapshot;
  StreamController _snapshotFetch;

  List<ByteData> _chunksInProgress;

  void _loadHeapSnapshot(ServiceEvent event) {
    if (_snapshotFetch == null || _snapshotFetch.isClosed) {
      // No outstanding snapshot request. Presumably another client asked for a
      // snapshot.
      Logger.root.info("Dropping unsolicited heap snapshot chunk");
      return;
    }

    // Occasionally these actually arrive out of order.
    var chunkIndex = event.chunkIndex;
    var chunkCount = event.chunkCount;
    if (_chunksInProgress == null) {
      _chunksInProgress = new List(chunkCount);
    }
    _chunksInProgress[chunkIndex] = event.data;
    _snapshotFetch.add("Receiving snapshot chunk ${chunkIndex + 1}"
                       " of $chunkCount...");

    for (var i = 0; i < chunkCount; i++) {
      if (_chunksInProgress[i] == null) return;
    }

    var loadedChunks = _chunksInProgress;
    _chunksInProgress = null;

    latestSnapshot = new HeapSnapshot(this, loadedChunks, event.nodeCount);
    if (_snapshotFetch != null) {
      latestSnapshot.graph.process(_snapshotFetch).then((graph) {
        _snapshotFetch.add(latestSnapshot);
        _snapshotFetch.close();
      });
    }
  }

  Stream fetchHeapSnapshot() {
    if (_snapshotFetch == null || _snapshotFetch.isClosed) {
      _snapshotFetch = new StreamController();
      // isolate.vm.streamListen('_Graph');
      isolate.invokeRpcNoUpgrade('_requestHeapSnapshot', {});
    }
    return _snapshotFetch.stream;
  }

  void updateHeapsFromMap(ObservableMap map) {
    newSpace.update(map['new']);
    oldSpace.update(map['old']);
  }

  void _update(ObservableMap map, bool mapIsRef) {
    name = map['name'];
    vmName = map['name'];
    number = int.parse(map['number'], onError:(_) => null);
    if (mapIsRef) {
      return;
    }
    _loaded = true;
    loading = false;

    _upgradeCollection(map, isolate);
    rootLibrary = map['rootLib'];
    if (map['entry'] != null) {
      entry = map['entry'];
    }
    var startTimeInMillis = map['startTime'];
    startTime = new DateTime.fromMillisecondsSinceEpoch(startTimeInMillis);
    notifyPropertyChange(#upTime, 0, 1);
    var countersMap = map['_tagCounters'];
    if (countersMap != null) {
      var names = countersMap['names'];
      var counts = countersMap['counters'];
      assert(names.length == counts.length);
      var sum = 0;
      for (var i = 0; i < counts.length; i++) {
        sum += counts[i];
      }
      // TODO: Why does this not work without this?
      counters = toObservable({});
      if (sum == 0) {
        for (var i = 0; i < names.length; i++) {
          counters[names[i]] = '0.0%';
        }
      } else {
        for (var i = 0; i < names.length; i++) {
          counters[names[i]] =
              (counts[i] / sum * 100.0).toStringAsFixed(2) + '%';
        }
      }
    }
    var timerMap = {};
    map['timers'].forEach((timer) {
        timerMap[timer['name']] = timer['time'];
      });
    timers['total'] = timerMap['time_total_runtime'];
    timers['compile'] = timerMap['time_compilation'];
    timers['gc'] = 0.0;  // TODO(turnidge): Export this from VM.
    timers['init'] = (timerMap['time_script_loading'] +
                      timerMap['time_creating_snapshot'] +
                      timerMap['time_isolate_initialization'] +
                      timerMap['time_bootstrap']);
    timers['dart'] = timerMap['time_dart_execution'];

    updateHeapsFromMap(map['_heaps']);
    _updateBreakpoints(map['breakpoints']);
    exceptionsPauseInfo = map['_debuggerSettings']['_exceptions'];

    pauseEvent = map['pauseEvent'];
    _updateRunState();
    error = map['error'];

    libraries.clear();
    libraries.addAll(map['libraries']);
    libraries.sort(ServiceObject.LexicalSortName);
  }

  Future<TagProfile> updateTagProfile() {
    return isolate.invokeRpcNoUpgrade('_getTagProfile', {}).then(
      (ObservableMap map) {
        var seconds = new DateTime.now().millisecondsSinceEpoch / 1000.0;
        tagProfile._processTagProfile(seconds, map);
        return tagProfile;
      });
  }

  ObservableMap<int, Breakpoint> breakpoints = new ObservableMap();
  String exceptionsPauseInfo;

  void _updateBreakpoints(List newBpts) {
    // Build a set of new breakpoints.
    var newBptSet = new Set();
    newBpts.forEach((bpt) => newBptSet.add(bpt.number));

    // Remove any old breakpoints which no longer exist.
    List toRemove = [];
    breakpoints.forEach((key, _) {
      if (!newBptSet.contains(key)) {
        toRemove.add(key);
      }
    });
    toRemove.forEach((key) => breakpoints.remove(key));

    // Add all new breakpoints.
    newBpts.forEach((bpt) => (breakpoints[bpt.number] = bpt));
  }

  void _addBreakpoint(Breakpoint bpt) {
    breakpoints[bpt.number] = bpt;
  }

  void _removeBreakpoint(Breakpoint bpt) {
    breakpoints.remove(bpt.number);
    bpt.remove();
  }

  void _onEvent(ServiceEvent event) {
    switch(event.kind) {
      case ServiceEvent.kIsolateStart:
      case ServiceEvent.kIsolateExit:
      case ServiceEvent.kInspect:
        // Handled elsewhere.
        break;

      case ServiceEvent.kBreakpointAdded:
        _addBreakpoint(event.breakpoint);
        break;

      case ServiceEvent.kIsolateUpdate:
      case ServiceEvent.kBreakpointResolved:
      case ServiceEvent.kDebuggerSettingsUpdate:
        // Update occurs as side-effect of caching.
        break;

      case ServiceEvent.kBreakpointRemoved:
        _removeBreakpoint(event.breakpoint);
        break;

      case ServiceEvent.kPauseStart:
      case ServiceEvent.kPauseExit:
      case ServiceEvent.kPauseBreakpoint:
      case ServiceEvent.kPauseInterrupted:
      case ServiceEvent.kPauseException:
      case ServiceEvent.kResume:
        pauseEvent = event;
        _updateRunState();
        break;

      case ServiceEvent.kGraph:
        _loadHeapSnapshot(event);
        break;

      case ServiceEvent.kGC:
        // Ignore GC events for now.
        break;

      default:
        // Log unrecognized events.
        Logger.root.severe('Unrecognized event: $event');
        break;
    }
  }

  Future<ServiceObject> addBreakpoint(Script script, int line) async {
    // TODO(turnidge): Pass line as an int instead of a string.
    try {
      Map params = {
        'scriptId': script.id,
        'line': '$line',
      };
      Breakpoint bpt = await invokeRpc('addBreakpoint', params);
      if (bpt.resolved &&
          script.loaded &&
          script.tokenToLine(bpt.location.tokenPos) != line) {
        // TODO(turnidge): Can this still happen?
        script.getLine(line).possibleBpt = false;
      }
      return bpt;
    } on ServerRpcException catch(e) {
      if (e.code == ServerRpcException.kCannotAddBreakpoint) {
        // Unable to set a breakpoint at the desired line.
        script.getLine(line).possibleBpt = false;
      }
      rethrow;
    }
  }

  Future<ServiceObject> addBreakpointAtEntry(ServiceFunction function) {
    return invokeRpc('addBreakpointAtEntry',
                     { 'functionId': function.id });
  }

  Future<ServiceObject> addBreakOnActivation(Instance closure) {
    return invokeRpc('_addBreakpointAtActivation',
                     { 'objectId': closure.id });
  }

  Future removeBreakpoint(Breakpoint bpt) {
    return invokeRpc('removeBreakpoint',
                     { 'breakpointId': bpt.id });
  }

  Future pause() {
    return invokeRpc('pause', {});
  }

  Future resume() {
    return invokeRpc('resume', {});
  }

  Future stepInto() {
    return invokeRpc('resume', {'step': 'Into'});
  }

  Future stepOver() {
    return invokeRpc('resume', {'step': 'Over'});
  }

  Future stepOut() {
    return invokeRpc('resume', {'step': 'Out'});
  }

  Future setName(String newName) {
    return invokeRpc('setName', {'name': newName});
  }

  Future setExceptionPauseInfo(String exceptions) {
    return invokeRpc('_setExceptionPauseInfo', {'exceptions': exceptions});
  }

  Future<ServiceMap> getStack() {
    return invokeRpc('getStack', {});
  }

  Future<ServiceObject> _eval(ServiceObject target,
                              String expression) {
    Map params = {
      'targetId': target.id,
      'expression': expression,
    };
    return invokeRpc('evaluate', params);
  }

  Future<ServiceObject> evalFrame(int frameIndex,
                                  String expression) {
    Map params = {
      'frameIndex': frameIndex,
      'expression': expression,
    };
    return invokeRpc('evaluateInFrame', params);
  }

  Future<ServiceObject> getRetainedSize(ServiceObject target) {
    Map params = {
      'targetId': target.id,
    };
    return invokeRpc('_getRetainedSize', params);
  }

  Future<ServiceObject> getRetainingPath(ServiceObject target, var limit) {
    Map params = {
      'targetId': target.id,
      'limit': limit.toString(),
    };
    return invokeRpc('_getRetainingPath', params);
  }

  Future<ServiceObject> getInboundReferences(ServiceObject target, var limit) {
    Map params = {
      'targetId': target.id,
      'limit': limit.toString(),
    };
    return invokeRpc('_getInboundReferences', params);
  }

  Future<ServiceObject> getTypeArgumentsList(bool onlyWithInstantiations) {
    Map params = {
      'onlyWithInstantiations': onlyWithInstantiations,
    };
    return invokeRpc('_getTypeArgumentsList', params);
  }

  Future<ServiceObject> getInstances(Class cls, var limit) {
    Map params = {
      'classId': cls.id,
      'limit': limit.toString(),
    };
    return invokeRpc('_getInstances', params);
  }

  Future<ServiceObject> getObjectByAddress(String address, [bool ref=true]) {
    Map params = {
      'address': address,
      'ref': ref,
    };
    return invokeRpc('_getObjectByAddress', params);
  }

  final ObservableMap<String, ServiceMetric> dartMetrics =
      new ObservableMap<String, ServiceMetric>();

  final ObservableMap<String, ServiceMetric> nativeMetrics =
      new ObservableMap<String, ServiceMetric>();

  Future<ObservableMap<String, ServiceMetric>> _refreshMetrics(
      String metricType,
      ObservableMap<String, ServiceMetric> metricsMap) {
    return invokeRpc('_getIsolateMetricList',
                     { 'type': metricType }).then((result) {
      // Clear metrics map.
      metricsMap.clear();
      // Repopulate metrics map.
      var metrics = result['metrics'];
      for (var metric in metrics) {
        metricsMap[metric.id] = metric;
      }
      return metricsMap;
    });
  }

  Future<ObservableMap<String, ServiceMetric>> refreshDartMetrics() {
    return _refreshMetrics('Dart', dartMetrics);
  }

  Future<ObservableMap<String, ServiceMetric>> refreshNativeMetrics() {
    return _refreshMetrics('Native', nativeMetrics);
  }

  Future refreshMetrics() {
    return Future.wait([refreshDartMetrics(), refreshNativeMetrics()]);
  }

  String toString() => "Isolate($_id)";
}

/// A [ServiceObject] which implements [ObservableMap].
class ServiceMap extends ServiceObject implements ObservableMap {
  final ObservableMap _map = new ObservableMap();
  static String objectIdRingPrefix = 'objects/';

  bool get canCache {
    return (_type == 'Class' ||
            _type == 'Function' ||
            _type == 'Field') &&
           !_id.startsWith(objectIdRingPrefix);
  }
  bool get immutable => false;

  ServiceMap._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    _loaded = !mapIsRef;

    _upgradeCollection(map, owner);
    // TODO(turnidge): Currently _map.clear() prevents us from
    // upgrading an already upgraded submap.  Is clearing really the
    // right thing to do here?
    _map.clear();
    _map.addAll(map);

    name = _map['name'];
    vmName = (_map.containsKey('vmName') ? _map['vmName'] : name);
  }

  // TODO(turnidge): These are temporary until we have a proper root
  // object for all dart heap objects.
  int get size => _map['size'];
  int get clazz => _map['class'];

  // Forward Map interface calls.
  void addAll(Map other) => _map.addAll(other);
  void clear() => _map.clear();
  bool containsValue(v) => _map.containsValue(v);
  bool containsKey(k) => _map.containsKey(k);
  void forEach(Function f) => _map.forEach(f);
  putIfAbsent(key, Function ifAbsent) => _map.putIfAbsent(key, ifAbsent);
  void remove(key) => _map.remove(key);
  operator [](k) => _map[k];
  operator []=(k, v) => _map[k] = v;
  bool get isEmpty => _map.isEmpty;
  bool get isNotEmpty => _map.isNotEmpty;
  Iterable get keys => _map.keys;
  Iterable get values => _map.values;
  int get length => _map.length;

  // Forward ChangeNotifier interface calls.
  bool deliverChanges() => _map.deliverChanges();
  void notifyChange(ChangeRecord record) => _map.notifyChange(record);
  notifyPropertyChange(Symbol field, Object oldValue, Object newValue) =>
      _map.notifyPropertyChange(field, oldValue, newValue);
  void observed() => _map.observed();
  void unobserved() => _map.unobserved();
  Stream<List<ChangeRecord>> get changes => _map.changes;
  bool get hasObservers => _map.hasObservers;

  String toString() => "ServiceMap($_map)";
}

/// A [DartError] is peered to a Dart Error object.
class DartError extends ServiceObject {
  DartError._empty(ServiceObject owner) : super._empty(owner);

  @observable String message;
  @observable Instance exception;
  @observable Instance stacktrace;

  void _update(ObservableMap map, bool mapIsRef) {
    message = map['message'];
    exception = new ServiceObject._fromMap(owner, map['exception']);
    stacktrace = new ServiceObject._fromMap(owner, map['stacktrace']);
    name = 'DartError($message)';
    vmName = name;
  }

  String toString() => 'DartError($message)';
}

/// A [ServiceEvent] is an asynchronous event notification from the vm.
class ServiceEvent extends ServiceObject {
  /// The possible 'kind' values.
  static const kIsolateStart           = 'IsolateStart';
  static const kIsolateExit            = 'IsolateExit';
  static const kIsolateUpdate          = 'IsolateUpdate';
  static const kPauseStart             = 'PauseStart';
  static const kPauseExit              = 'PauseExit';
  static const kPauseBreakpoint        = 'PauseBreakpoint';
  static const kPauseInterrupted       = 'PauseInterrupted';
  static const kPauseException         = 'PauseException';
  static const kResume                 = 'Resume';
  static const kBreakpointAdded        = 'BreakpointAdded';
  static const kBreakpointResolved     = 'BreakpointResolved';
  static const kBreakpointRemoved      = 'BreakpointRemoved';
  static const kGraph                  = '_Graph';
  static const kGC                     = 'GC';
  static const kInspect                = 'Inspect';
  static const kDebuggerSettingsUpdate = '_DebuggerSettingsUpdate';
  static const kConnectionClosed       = 'ConnectionClosed';

  ServiceEvent._empty(ServiceObjectOwner owner) : super._empty(owner);

  ServiceEvent.connectionClosed(this.reason) : super._empty(null) {
    kind = kConnectionClosed;
  }

  @observable String kind;
  @observable Breakpoint breakpoint;
  @observable Frame topFrame;
  @observable Instance exception;
  @observable ServiceObject inspectee;
  @observable ByteData data;
  @observable int count;
  @observable String reason;
  @observable String exceptions;
  int chunkIndex, chunkCount, nodeCount;

  @observable bool get isPauseEvent {
    return (kind == kPauseStart ||
            kind == kPauseExit ||
            kind == kPauseBreakpoint ||
            kind == kPauseInterrupted ||
            kind == kPauseException);
  }

  void _update(ObservableMap map, bool mapIsRef) {
    _loaded = true;
    _upgradeCollection(map, owner);
    assert(map['isolate'] == null || owner == map['isolate']);
    kind = map['kind'];
    notifyPropertyChange(#isPauseEvent, 0, 1);
    name = 'ServiceEvent $kind';
    vmName = name;
    if (map['breakpoint'] != null) {
      breakpoint = map['breakpoint'];
    }
    // TODO(turnidge): Expose the full list of breakpoints.  For now
    // we just pretend like there is only one active breakpoint.
    if (map['pauseBreakpoints'] != null) {
      var pauseBpts = map['pauseBreakpoints'];
      if (pauseBpts.length > 0) {
        breakpoint = pauseBpts[0];
      }
    }
    topFrame = map['topFrame'];
    if (map['exception'] != null) {
      exception = map['exception'];
    }
    if (map['inspectee'] != null) {
      inspectee = map['inspectee'];
    }
    if (map['_data'] != null) {
      data = map['_data'];
    }
    if (map['chunkIndex'] != null) {
      chunkIndex = map['chunkIndex'];
    }
    if (map['chunkCount'] != null) {
      chunkCount = map['chunkCount'];
    }
    if (map['nodeCount'] != null) {
      nodeCount = map['nodeCount'];
    }
    if (map['count'] != null) {
      count = map['count'];
    }
    if (map['_debuggerSettings'] != null &&
        map['_debuggerSettings']['_exceptions'] != null) {
      exceptions = map['_debuggerSettings']['_exceptions'];
    }
  }

  String toString() {
    if (data == null) {
      return "ServiceEvent(owner='${owner.id}', kind='${kind}')";
    } else {
      return "ServiceEvent(owner='${owner.id}', kind='${kind}', "
          "data.lengthInBytes=${data.lengthInBytes})";
    }
  }
}

class Breakpoint extends ServiceObject {
  Breakpoint._empty(ServiceObjectOwner owner) : super._empty(owner);

  // TODO(turnidge): Add state to track if a breakpoint has been
  // removed from the program.  Remove from the cache when deleted.
  bool get canCache => true;
  bool get immutable => false;

  // A unique integer identifier for this breakpoint.
  @observable int number;

  // Source location information.
  @observable SourceLocation location;

  // The breakpoint has been assigned to a final source location.
  @observable bool resolved;

  void _update(ObservableMap map, bool mapIsRef) {
    _loaded = true;
    _upgradeCollection(map, owner);

    var newNumber = map['breakpointNumber'];
    // number never changes.
    assert((number == null) || (number == newNumber));
    number = newNumber;

    resolved = map['resolved'];

    var oldLocation = location;
    var newLocation = map['location'];
    var oldScript;
    var newScript;
    var oldTokenPos;
    var newTokenPos;
    if (oldLocation != null) {
      oldScript = location.script;
      oldTokenPos = location.tokenPos;
    }
    if (newLocation != null) {
      newScript = newLocation.script;
      newTokenPos = newLocation.tokenPos;
    }
    // script never changes
    assert((oldScript == null) || (oldScript == newScript));
    bool tokenPosChanged = oldTokenPos != newTokenPos;
    if (newScript.loaded &&
        (newTokenPos != null) &&
        tokenPosChanged) {
      // The breakpoint has moved.  Remove it and add it later.
      if (oldScript != null) {
        oldScript._removeBreakpoint(this);
      }
    }
    location = newLocation;
    if (newScript.loaded && tokenPosChanged) {
      newScript._addBreakpoint(this);
    }
  }

  void remove() {
    // Remove any references to this breakpoint.  It has been removed.
    location.script._removeBreakpoint(this);
    if ((isolate.pauseEvent != null) &&
        (isolate.pauseEvent.breakpoint != null) &&
        (isolate.pauseEvent.breakpoint.id == id)) {
      isolate.pauseEvent.breakpoint = null;
    }
  }

  String toString() {
    if (number != null) {
      return 'Breakpoint ${number} at ${location})';
    } else {
      return 'Uninitialized breakpoint';
    }
  }
}


class LibraryDependency {
  @reflectable final bool isImport;
  @reflectable final bool isDeferred;
  @reflectable final String prefix;
  @reflectable final Library target;

  bool get isExport => !isImport;

  LibraryDependency._(this.isImport, this.isDeferred, this.prefix, this.target);

  static _fromMap(map) => new LibraryDependency._(map["isImport"],
                                                  map["isDeferred"],
                                                  map["prefix"],
                                                  map["target"]);
}


class Library extends ServiceObject with Coverage {
  @observable String uri;
  @reflectable final dependencies = new ObservableList<LibraryDependency>();
  @reflectable final scripts = new ObservableList<Script>();
  @reflectable final classes = new ObservableList<Class>();
  @reflectable final variables = new ObservableList<Field>();
  @reflectable final functions = new ObservableList<ServiceFunction>();

  bool get canCache => true;
  bool get immutable => false;

  Library._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    uri = map['uri'];
    var shortUri = uri;
    if (uri.startsWith('file://') ||
        uri.startsWith('http://')) {
      shortUri = uri.substring(uri.lastIndexOf('/') + 1);
    }
    name = map['name'];
    if (name.isEmpty) {
      // When there is no name for a library, use the shortUri.
      name = shortUri;
    }
    vmName = (map.containsKey('vmName') ? map['vmName'] : name);
    if (mapIsRef) {
      return;
    }
    _loaded = true;
    _upgradeCollection(map, isolate);
    dependencies.clear();
    dependencies.addAll(map["dependencies"].map(LibraryDependency._fromMap));
    scripts.clear();
    scripts.addAll(removeDuplicatesAndSortLexical(map['scripts']));
    classes.clear();
    classes.addAll(map['classes']);
    classes.sort(ServiceObject.LexicalSortName);
    variables.clear();
    variables.addAll(map['variables']);
    variables.sort(ServiceObject.LexicalSortName);
    functions.clear();
    functions.addAll(map['functions']);
    functions.sort(ServiceObject.LexicalSortName);
  }

  Future<ServiceObject> evaluate(String expression) {
    return isolate._eval(this, expression);
  }

  String toString() => "Library($uri)";
}

class AllocationCount extends Observable {
  @observable int instances = 0;
  @observable int bytes = 0;

  void reset() {
    instances = 0;
    bytes = 0;
  }

  bool get empty => (instances == 0) && (bytes == 0);
}

class Allocations {
  // Indexes into VM provided array. (see vm/class_table.h).
  static const ALLOCATED_BEFORE_GC = 0;
  static const ALLOCATED_BEFORE_GC_SIZE = 1;
  static const LIVE_AFTER_GC = 2;
  static const LIVE_AFTER_GC_SIZE = 3;
  static const ALLOCATED_SINCE_GC = 4;
  static const ALLOCATED_SINCE_GC_SIZE = 5;
  static const ACCUMULATED = 6;
  static const ACCUMULATED_SIZE = 7;

  final AllocationCount accumulated = new AllocationCount();
  final AllocationCount current = new AllocationCount();

  void update(List stats) {
    accumulated.instances = stats[ACCUMULATED];
    accumulated.bytes = stats[ACCUMULATED_SIZE];
    current.instances = stats[LIVE_AFTER_GC] + stats[ALLOCATED_SINCE_GC];
    current.bytes = stats[LIVE_AFTER_GC_SIZE] + stats[ALLOCATED_SINCE_GC_SIZE];
  }

  bool get empty => accumulated.empty && current.empty;
}

class Class extends ServiceObject with Coverage {
  @observable Library library;

  @observable bool isAbstract;
  @observable bool isConst;
  @observable bool isFinalized;
  @observable bool isPatch;
  @observable bool isImplemented;

  @observable SourceLocation location;

  @observable ServiceMap error;
  @observable int vmCid;

  final Allocations newSpace = new Allocations();
  final Allocations oldSpace = new Allocations();
  final AllocationCount promotedByLastNewGC = new AllocationCount();

  @observable bool get hasNoAllocations => newSpace.empty && oldSpace.empty;

  @reflectable final fields = new ObservableList<Field>();
  @reflectable final functions = new ObservableList<ServiceFunction>();

  @observable Class superclass;
  @reflectable final interfaces = new ObservableList<Instance>();
  @reflectable final subclasses = new ObservableList<Class>();

  bool get canCache => true;
  bool get immutable => false;

  Class._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    name = map['name'];
    vmName = (map.containsKey('vmName') ? map['vmName'] : name);
    var idPrefix = "classes/";
    assert(id.startsWith(idPrefix));
    vmCid = int.parse(id.substring(idPrefix.length));

    if (mapIsRef) {
      return;
    }

    // We are fully loaded.
    _loaded = true;

    // Extract full properties.
    _upgradeCollection(map, isolate);

    // Some builtin classes aren't associated with a library.
    if (map['library'] is Library) {
      library = map['library'];
    } else {
      library = null;
    }

    location = map['location'];
    isAbstract = map['abstract'];
    isConst = map['const'];
    isFinalized = map['_finalized'];
    isPatch = map['_patch'];
    isImplemented = map['_implemented'];

    subclasses.clear();
    subclasses.addAll(map['subclasses']);
    subclasses.sort(ServiceObject.LexicalSortName);

    interfaces.clear();
    interfaces.addAll(map['interfaces']);
    interfaces.sort(ServiceObject.LexicalSortName);

    fields.clear();
    fields.addAll(map['fields']);
    fields.sort(ServiceObject.LexicalSortName);

    functions.clear();
    functions.addAll(map['functions']);
    functions.sort(ServiceObject.LexicalSortName);

    superclass = map['super'];
    // Work-around Object not tracking its subclasses in the VM.
    if (superclass != null && superclass.name == "Object") {
      superclass._addSubclass(this);
    }
    error = map['error'];

    var allocationStats = map['_allocationStats'];
    if (allocationStats != null) {
      newSpace.update(allocationStats['new']);
      oldSpace.update(allocationStats['old']);
      notifyPropertyChange(#hasNoAllocations, 0, 1);
      promotedByLastNewGC.instances = allocationStats['promotedInstances'];
      promotedByLastNewGC.bytes = allocationStats['promotedBytes'];
    }
  }

  void _addSubclass(Class subclass) {
    if (subclasses.contains(subclass)) {
      return;
    }
    subclasses.add(subclass);
    subclasses.sort(ServiceObject.LexicalSortName);
  }

  Future<ServiceObject> evaluate(String expression) {
    return isolate._eval(this, expression);
  }

  String toString() => 'Class($vmName)';
}

class Instance extends ServiceObject {
  @observable String kind;
  @observable Class clazz;
  @observable int size;
  @observable int retainedSize;
  @observable String valueAsString;  // If primitive.
  @observable bool valueAsStringIsTruncated;
  @observable ServiceFunction function;  // If a closure.
  @observable Context context;  // If a closure.
  @observable String name;  // If a Type.
  @observable int length; // If a List, Map or TypedData.

  @observable var typeClass;
  @observable var fields;
  @observable var nativeFields;
  @observable var elements;  // If a List.
  @observable var associations;  // If a Map.
  @observable var typedElements;  // If a TypedData.
  @observable var referent;  // If a MirrorReference.
  @observable Instance key;  // If a WeakProperty.
  @observable Instance value;  // If a WeakProperty.
  @observable Breakpoint activationBreakpoint;  // If a Closure.

  bool get isAbstractType {
    return (kind == 'Type' || kind == 'TypeRef' ||
            kind == 'TypeParameter' || kind == 'BoundedType');
  }
  bool get isNull => kind == 'Null';
  bool get isBool => kind == 'Bool';
  bool get isDouble => kind == 'Double';
  bool get isString => kind == 'String';
  bool get isInt => kind == 'Int';
  bool get isList => kind == 'List';
  bool get isMap => kind == 'Map';
  bool get isTypedData {
    return kind == 'Uint8ClampedList'
        || kind == 'Uint8List'
        || kind == 'Uint16List'
        || kind == 'Uint32List'
        || kind == 'Uint64List'
        || kind == 'Int8List'
        || kind == 'Int16List'
        || kind == 'Int32List'
        || kind == 'Int64List'
        || kind == 'Float32List'
        || kind == 'Float64List'
        || kind == 'Int32x4List'
        || kind == 'Float32x4List'
        || kind == 'Float64x2List';
  }
  bool get isMirrorReference => kind == 'MirrorReference';
  bool get isWeakProperty => kind == 'WeakProperty';
  bool get isClosure => kind == 'Closure';

  // TODO(turnidge): Is this properly backwards compatible when new
  // instance kinds are added?
  bool get isPlainInstance => kind == 'PlainInstance';

  Instance._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    // Extract full properties.
    _upgradeCollection(map, isolate);

    kind = map['kind'];
    clazz = map['class'];
    size = map['size'];
    valueAsString = map['valueAsString'];
    // Coerce absence to false.
    valueAsStringIsTruncated = map['valueAsStringIsTruncated'] == true;
    function = map['closureFunction'];
    context = map['closureContext'];
    name = map['name'];
    length = map['length'];

    if (mapIsRef) {
      return;
    }

    nativeFields = map['_nativeFields'];
    fields = map['fields'];
    elements = map['elements'];
    associations = map['associations'];
    if (map['bytes'] != null) {
      var bytes = decodeBase64(map['bytes']);
      switch (map['kind']) {
        case "Uint8ClampedList":
          typedElements = bytes.buffer.asUint8ClampedList(); break;
        case "Uint8List":
          typedElements = bytes.buffer.asUint8List(); break;
        case "Uint16List":
          typedElements = bytes.buffer.asUint16List(); break;
        case "Uint32List":
          typedElements = bytes.buffer.asUint32List(); break;
        case "Uint64List":
          typedElements = bytes.buffer.asUint64List(); break;
        case "Int8List":
          typedElements = bytes.buffer.asInt8List(); break;
        case "Int16List":
          typedElements = bytes.buffer.asInt16List(); break;
        case "Int32List":
          typedElements = bytes.buffer.asInt32List(); break;
        case "Int64List":
          typedElements = bytes.buffer.asInt64List(); break;
        case "Float32List":
          typedElements = bytes.buffer.asFloat32List(); break;
        case "Float64List":
          typedElements = bytes.buffer.asFloat64List(); break;
        case "Int32x4List":
          typedElements = bytes.buffer.asInt32x4List(); break;
        case "Float32x4List":
          typedElements = bytes.buffer.asFloat32x4List(); break;
        case "Float64x2List":
          typedElements = bytes.buffer.asFloat64x2List(); break;
      }
    }
    typeClass = map['typeClass'];
    referent = map['mirrorReferent'];
    key = map['propertyKey'];
    value = map['propertyValue'];
    activationBreakpoint = map['_activationBreakpoint'];

    // We are fully loaded.
    _loaded = true;
  }

  String get shortName {
    if (isClosure) {
      return function.qualifiedName;
    }
    if (valueAsString != null) {
      return valueAsString;
    }
    return 'a ${clazz.name}';
  }

  Future<ServiceObject> evaluate(String expression) {
    return isolate._eval(this, expression);
  }

  String toString() => 'Instance($shortName)';
}


class Context extends ServiceObject {
  @observable Class clazz;
  @observable int size;

  @observable var parentContext;
  @observable int length;
  @observable var variables;

  Context._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    // Extract full properties.
    _upgradeCollection(map, isolate);

    size = map['size'];
    length = map['length'];
    parentContext = map['parent'];

    if (mapIsRef) {
      return;
    }

    clazz = map['class'];
    variables = map['variables'];

    // We are fully loaded.
    _loaded = true;
  }

  String toString() => 'Context($length)';
}


// TODO(koda): Sync this with VM.
class FunctionKind {
  final String _strValue;
  FunctionKind._internal(this._strValue);
  toString() => _strValue;
  bool isSynthetic() => [kCollected, kNative, kStub, kTag].contains(this);
  bool isDart() => !isSynthetic();
  bool isStub() => (this == kStub);
  bool hasDartCode() => isDart() || isStub();
  static FunctionKind fromJSON(String value) {
    switch(value) {
      case 'RegularFunction': return kRegularFunction;
      case 'ClosureFunction': return kClosureFunction;
      case 'GetterFunction': return kGetterFunction;
      case 'SetterFunction': return kSetterFunction;
      case 'Constructor': return kConstructor;
      case 'ImplicitGetter': return kImplicitGetterFunction;
      case 'ImplicitSetter': return kImplicitSetterFunction;
      case 'ImplicitStaticFinalGetter': return kImplicitStaticFinalGetter;
      case 'IrregexpFunction': return kIrregexpFunction;
      case 'StaticInitializer': return kStaticInitializer;
      case 'MethodExtractor': return kMethodExtractor;
      case 'NoSuchMethodDispatcher': return kNoSuchMethodDispatcher;
      case 'InvokeFieldDispatcher': return kInvokeFieldDispatcher;
      case 'Collected': return kCollected;
      case 'Native': return kNative;
      case 'Stub': return kStub;
      case 'Tag': return kTag;
    }
    Logger.root.severe('Unrecognized function kind: $value');
    throw new FallThroughError();
  }

  static FunctionKind kRegularFunction = new FunctionKind._internal('function');
  static FunctionKind kClosureFunction = new FunctionKind._internal('closure function');
  static FunctionKind kGetterFunction = new FunctionKind._internal('getter function');
  static FunctionKind kSetterFunction = new FunctionKind._internal('setter function');
  static FunctionKind kConstructor = new FunctionKind._internal('constructor');
  static FunctionKind kImplicitGetterFunction = new FunctionKind._internal('implicit getter function');
  static FunctionKind kImplicitSetterFunction = new FunctionKind._internal('implicit setter function');
  static FunctionKind kImplicitStaticFinalGetter = new FunctionKind._internal('implicit static final getter');
  static FunctionKind kIrregexpFunction = new FunctionKind._internal('ir regexp function');
  static FunctionKind kStaticInitializer = new FunctionKind._internal('static initializer');
  static FunctionKind kMethodExtractor = new FunctionKind._internal('method extractor');
  static FunctionKind kNoSuchMethodDispatcher = new FunctionKind._internal('noSuchMethod dispatcher');
  static FunctionKind kInvokeFieldDispatcher = new FunctionKind._internal('invoke field dispatcher');
  static FunctionKind kCollected = new FunctionKind._internal('Collected');
  static FunctionKind kNative = new FunctionKind._internal('Native');
  static FunctionKind kTag = new FunctionKind._internal('Tag');
  static FunctionKind kStub = new FunctionKind._internal('Stub');
  static FunctionKind kUNKNOWN = new FunctionKind._internal('UNKNOWN');
}

class ServiceFunction extends ServiceObject with Coverage {
  // owner is a Library, Class, or ServiceFunction.
  @observable ServiceObject dartOwner;
  @observable Library library;
  @observable bool isStatic;
  @observable bool isConst;
  @observable SourceLocation location;
  @observable Code code;
  @observable Code unoptimizedCode;
  @observable bool isOptimizable;
  @observable bool isInlinable;
  @observable FunctionKind kind;
  @observable int deoptimizations;
  @observable String qualifiedName;
  @observable int usageCounter;
  @observable bool isDart;
  @observable ProfileFunction profile;

  bool get immutable => false;

  ServiceFunction._empty(ServiceObject owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    name = map['name'];
    vmName = (map.containsKey('vmName') ? map['vmName'] : name);

    _upgradeCollection(map, isolate);

    dartOwner = map['owner'];
    kind = FunctionKind.fromJSON(map['_kind']);
    isDart = !kind.isSynthetic();

    if (dartOwner is ServiceFunction) {
      ServiceFunction ownerFunction = dartOwner;
      library = ownerFunction.library;
      qualifiedName = "${ownerFunction.qualifiedName}.${name}";

    } else if (dartOwner is Class) {
      Class ownerClass = dartOwner;
      library = ownerClass.library;
      qualifiedName = "${ownerClass.name}.${name}";

    } else {
      library = dartOwner;
      qualifiedName = name;
    }

    if (mapIsRef) {
      return;
    }

    _loaded = true;
    isStatic = map['static'];
    isConst = map['const'];
    location = map['location'];
    code = map['code'];
    isOptimizable = map['_optimizable'];
    isInlinable = map['_inlinable'];
    unoptimizedCode = map['_unoptimizedCode'];
    deoptimizations = map['_deoptimizations'];
    usageCounter = map['_usageCounter'];
  }
}


class Field extends ServiceObject {
  // Library or Class.
  @observable ServiceObject dartOwner;
  @observable Library library;
  @observable Instance declaredType;
  @observable bool isStatic;
  @observable bool isFinal;
  @observable bool isConst;
  @observable Instance staticValue;
  @observable String name;
  @observable String vmName;

  @observable bool guardNullable;
  @observable var /* Class | String */ guardClass;
  @observable String guardLength;
  @observable SourceLocation location;

  Field._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    // Extract full properties.
    _upgradeCollection(map, isolate);

    name = map['name'];
    vmName = (map.containsKey('vmName') ? map['vmName'] : name);
    dartOwner = map['owner'];
    declaredType = map['declaredType'];
    isStatic = map['static'];
    isFinal = map['final'];
    isConst = map['const'];
    staticValue = map['staticValue'];

    if (dartOwner is Class) {
      Class ownerClass = dartOwner;
      library = ownerClass.library;

    } else {
      library = dartOwner;
    }

    if (mapIsRef) {
      return;
    }

    guardNullable = map['_guardNullable'];
    guardClass = map['_guardClass'];
    guardLength = map['_guardLength'];
    location = map['location'];
    _loaded = true;
  }

  String toString() => 'Field(${dartOwner.name}.$name)';
}


class ScriptLine extends Observable {
  final Script script;
  final int line;
  final String text;
  @observable int hits;
  @observable bool possibleBpt = true;
  @observable bool breakpointResolved = false;
  @observable Set<Breakpoint> breakpoints;

  bool get isBlank {
    // Compute isBlank on demand.
    if (_isBlank == null) {
      _isBlank = text.trim().isEmpty;
    }
    return _isBlank;
  }
  bool _isBlank;

  bool get isTrivialLine => !possibleBpt;

  static bool _isTrivialToken(String token) {
    if (token == 'else') {
      return true;
    }
    for (var c in token.split('')) {
      switch (c) {
        case '{':
        case '}':
        case '(':
        case ')':
        case ';':
          break;
        default:
          return false;
      }
    }
    return true;
  }

  static bool _isTrivialLine(String text) {
    if (text.trimLeft().startsWith('//')) {
      return true;
    }
    var wsTokens = text.split(new RegExp(r"(\s)+"));
    for (var wsToken in wsTokens) {
      var tokens = wsToken.split(new RegExp(r"(\b)"));
      for (var token in tokens) {
        if (!_isTrivialToken(token)) {
          return false;
        }
      }
    }
    return true;
  }

  ScriptLine(this.script, this.line, this.text) {
    possibleBpt = !_isTrivialLine(text);
  }

  void addBreakpoint(Breakpoint bpt) {
    if (breakpoints == null) {
      breakpoints = new Set<Breakpoint>();
    }
    breakpoints.add(bpt);
    breakpointResolved = breakpointResolved || bpt.resolved;
  }

  void removeBreakpoint(Breakpoint bpt) {
    assert(breakpoints != null && breakpoints.contains(bpt));
    breakpoints.remove(bpt);
    if (breakpoints.isEmpty) {
      breakpoints = null;
      breakpointResolved = false;
    }
  }
}

class CallSite {
  final String name;
  // TODO(turnidge): Use SourceLocation here instead.
  final Script script;
  final int tokenPos;
  final List<CallSiteEntry> entries;

  CallSite(this.name, this.script, this.tokenPos, this.entries);

  int get line => script.tokenToLine(tokenPos);
  int get column => script.tokenToCol(tokenPos);

  int get aggregateCount {
    var count = 0;
    for (var entry in entries) {
      count += entry.count;
    }
    return count;
  }

  factory CallSite.fromMap(Map siteMap, Script script) {
    var name = siteMap['name'];
    var tokenPos = siteMap['tokenPos'];
    var entries = new List<CallSiteEntry>();
    for (var entryMap in siteMap['cacheEntries']) {
      entries.add(new CallSiteEntry.fromMap(entryMap));
    }
    return new CallSite(name, script, tokenPos, entries);
  }

  operator ==(other) {
    return (script == other.script) && (tokenPos == other.tokenPos);
  }
  int get hashCode => (script.hashCode << 8) | tokenPos;

  String toString() => "CallSite($name, $tokenPos)";
}

class CallSiteEntry {
  final /* Class | Library */ receiverContainer;
  final int count;
  final ServiceFunction target;

  CallSiteEntry(this.receiverContainer, this.count, this.target);

  factory CallSiteEntry.fromMap(Map entryMap) {
    return new CallSiteEntry(entryMap['receiverContainer'],
                             entryMap['count'],
                             entryMap['target']);
  }

  String toString() => "CallSiteEntry(${receiverContainer.name}, $count)";
}

/// The location of a local variable reference in a script.
class LocalVarLocation {
  final int line;
  final int column;
  final int endColumn;
  LocalVarLocation(this.line, this.column, this.endColumn);
}

class Script extends ServiceObject with Coverage {
  Set<CallSite> callSites = new Set<CallSite>();
  final lines = new ObservableList<ScriptLine>();
  final _hits = new Map<int, int>();
  @observable String uri;
  @observable String kind;
  @observable int firstTokenPos;
  @observable int lastTokenPos;
  @observable int lineOffset;
  @observable int columnOffset;
  @observable Library library;

  bool get immutable => true;

  String _shortUri;

  Script._empty(ServiceObjectOwner owner) : super._empty(owner);

  ScriptLine getLine(int line) {
    assert(_loaded);
    assert(line >= 1);
    return lines[line - lineOffset - 1];
  }

  /// This function maps a token position to a line number.
  int tokenToLine(int token) => _tokenToLine[token];
  Map _tokenToLine = {};

  /// This function maps a token position to a column number.
  int tokenToCol(int token) => _tokenToCol[token];
  Map _tokenToCol = {};

  void _update(ObservableMap map, bool mapIsRef) {
    _upgradeCollection(map, isolate);
    uri = map['uri'];
    kind = map['_kind'];
    _shortUri = uri.substring(uri.lastIndexOf('/') + 1);
    name = _shortUri;
    vmName = uri;
    if (mapIsRef) {
      return;
    }
    _loaded = true;
    lineOffset = map['lineOffset'];
    columnOffset = map['columnOffset'];
    _parseTokenPosTable(map['tokenPosTable']);
    _processSource(map['source']);
    library = map['library'];
  }

  void _parseTokenPosTable(List<List<int>> table) {
    if (table == null) {
      return;
    }
    _tokenToLine.clear();
    _tokenToCol.clear();
    firstTokenPos = null;
    lastTokenPos = null;
    var lineSet = new Set();

    for (var line in table) {
      // Each entry begins with a line number...
      var lineNumber = line[0];
      lineSet.add(lineNumber);
      for (var pos = 1; pos < line.length; pos += 2) {
        // ...and is followed by (token offset, col number) pairs.
        var tokenOffset = line[pos];
        var colNumber = line[pos+1];
        if (firstTokenPos == null) {
          // Mark first token position.
          firstTokenPos = tokenOffset;
          lastTokenPos = tokenOffset;
        } else {
          // Keep track of max and min token positions.
          firstTokenPos = (firstTokenPos <= tokenOffset) ?
              firstTokenPos : tokenOffset;
          lastTokenPos = (lastTokenPos >= tokenOffset) ?
              lastTokenPos : tokenOffset;
        }
        _tokenToLine[tokenOffset] = lineNumber;
        _tokenToCol[tokenOffset] = colNumber;
      }
    }

    for (var line in lines) {
      // Remove possible breakpoints on lines with no tokens.
      if (!lineSet.contains(line.line)) {
        line.possibleBpt = false;
      }
    }
  }

  void _processCallSites(List newCallSiteMaps) {
    var mergedCallSites = new Set<CallSite>();
    for (var callSiteMap in newCallSiteMaps) {
      var newSite = new CallSite.fromMap(callSiteMap, this);
      mergedCallSites.add(newSite);

      var line = newSite.line;
      var hit = newSite.aggregateCount;
      assert(line >= 1); // Lines start at 1.
      var oldHits = _hits[line];
      if (oldHits != null) {
        hit += oldHits;
      }
      _hits[line] = hit;
    }

    mergedCallSites.addAll(callSites);
    callSites = mergedCallSites;
    _applyHitsToLines();
    // Notify any Observers that this Script's state has changed.
    notifyChange(null);
  }

  void _processSource(String source) {
    if (source == null) {
      return;
    }
    var sourceLines = source.split('\n');
    if (sourceLines.length == 0) {
      return;
    }
    lines.clear();
    Logger.root.info('Adding ${sourceLines.length} source lines for ${uri}');
    for (var i = 0; i < sourceLines.length; i++) {
      lines.add(new ScriptLine(this, i + lineOffset + 1, sourceLines[i]));
    }
    for (var bpt in isolate.breakpoints.values) {
      if (bpt.location.script == this) {
        _addBreakpoint(bpt);
      }
    }

    _applyHitsToLines();
    // Notify any Observers that this Script's state has changed.
    notifyChange(null);
  }

  void _applyHitsToLines() {
    for (var line in lines) {
      var hits = _hits[line.line];
      line.hits = hits;
    }
  }

  void _addBreakpoint(Breakpoint bpt) {
    var line = tokenToLine(bpt.location.tokenPos);
    getLine(line).addBreakpoint(bpt);
  }

  void _removeBreakpoint(Breakpoint bpt) {
    var line = tokenToLine(bpt.location.tokenPos);
    if (line != null) {
      getLine(line).removeBreakpoint(bpt);
    }
  }

  List<LocalVarLocation> scanLineForLocalVariableLocations(Pattern pattern,
                                                            String name,
                                                            String lineContents,
                                                            int lineNumber,
                                                            int columnOffset) {
    var r = <LocalVarLocation>[];

    pattern.allMatches(lineContents).forEach((Match match) {
      // We have a match but our regular expression may have matched extra
      // characters on either side of the name. Tighten the location.
      var nameStart = match.input.indexOf(name, match.start);
      var column = nameStart + columnOffset;
      var endColumn = column + name.length;
      var localVarLocation = new LocalVarLocation(lineNumber,
                                                  column,
                                                  endColumn);
      r.add(localVarLocation);
    });

    return r;
  }

  List<LocalVarLocation> scanForLocalVariableLocations(String name,
                                                       int tokenPos,
                                                       int endTokenPos) {
    // A pattern that matches:
    // start of line OR non-(alpha numeric OR period) character followed by
    // name followed by
    // a non-alpha numerc character.
    //
    // NOTE: This pattern can over match on both ends. This is corrected for
    // [scanLineForLocalVariableLocationse].
    var pattern = new RegExp("(^|[^A-Za-z0-9\.])$name[^A-Za-z0-9]");

    // Result.
    var r = <LocalVarLocation>[];

    // Limits.
    final lastLine = tokenToLine(endTokenPos);
    if (lastLine == null) {
      return r;
    }

    var lastColumn = tokenToCol(endTokenPos);
    if (lastColumn == null) {
      return r;
    }
    // Current scan position.
    var line = tokenToLine(tokenPos);
    if (line == null) {
      return r;
    }
    var column = tokenToCol(tokenPos);
    if (column == null) {
      return r;
    }

    // Move back by name length.
    // TODO(johnmccutchan): Fix LocalVarDescriptor to set column before the
    // identifier name.
    column = math.max(0, column - name.length);

    var lineContents;

    if (line == lastLine) {
      // Only one line.
      if (!getLine(line).isTrivialLine) {
        // TODO(johnmccutchan): end token pos -> column can lie for snapshotted
        // code. e.g.:
        // io_sink.dart source line 23 ends at column 39
        // io_sink.dart snapshotted source line 23 ends at column 35.
        lastColumn = math.min(getLine(line).text.length, lastColumn);
        lineContents = getLine(line).text.substring(column, lastColumn - 1);
        return scanLineForLocalVariableLocations(pattern,
                                                  name,
                                                  lineContents,
                                                  line,
                                                  column);
      }
    }

    // Scan first line.
    if (!getLine(line).isTrivialLine) {
      lineContents = getLine(line).text.substring(column);
      r.addAll(scanLineForLocalVariableLocations(pattern,
                                                  name,
                                                  lineContents,
                                                  line++,
                                                  column));
    }

    // Scan middle lines.
    while (line < (lastLine - 1)) {
      if (getLine(line).isTrivialLine) {
        line++;
        continue;
      }
      lineContents = getLine(line).text;
      r.addAll(
          scanLineForLocalVariableLocations(pattern,
                                             name,
                                             lineContents,
                                             line++,
                                             0));
    }

    // Scan last line.
    if (!getLine(line).isTrivialLine) {
      // TODO(johnmccutchan): end token pos -> column can lie for snapshotted
      // code. e.g.:
      // io_sink.dart source line 23 ends at column 39
      // io_sink.dart snapshotted source line 23 ends at column 35.
      lastColumn = math.min(getLine(line).text.length, lastColumn);
      lineContents = getLine(line).text.substring(0, lastColumn - 1);
      r.addAll(
          scanLineForLocalVariableLocations(pattern,
                                             name,
                                             lineContents,
                                             line,
                                             0));
    }
    return r;
  }
}

class PcDescriptor extends Observable {
  final int pcOffset;
  @reflectable final int deoptId;
  @reflectable final int tokenPos;
  @reflectable final int tryIndex;
  @reflectable final String kind;
  @observable Script script;
  @observable String formattedLine;
  PcDescriptor(this.pcOffset, this.deoptId, this.tokenPos, this.tryIndex,
               this.kind);

  @reflectable String formattedDeoptId() {
    if (deoptId == -1) {
      return 'N/A';
    }
    return deoptId.toString();
  }

  @reflectable String formattedTokenPos() {
    if (tokenPos == -1) {
      return '';
    }
    return tokenPos.toString();
  }

  void processScript(Script script) {
    this.script = null;
    if (tokenPos == -1) {
      return;
    }
    var line = script.tokenToLine(tokenPos);
    if (line == null) {
      return;
    }
    this.script = script;
    var scriptLine = script.getLine(line);
    formattedLine = scriptLine.text;
  }
}

class PcDescriptors extends ServiceObject {
  @observable Class clazz;
  @observable int size;
  bool get canCache => false;
  bool get immutable => true;
  @reflectable final List<PcDescriptor> descriptors =
      new ObservableList<PcDescriptor>();

  PcDescriptors._empty(ServiceObjectOwner owner) : super._empty(owner) {
  }

  void _update(ObservableMap m, bool mapIsRef) {
    if (mapIsRef) {
      return;
    }
    _upgradeCollection(m, isolate);
    clazz = m['class'];
    size = m['size'];
    descriptors.clear();
    for (var descriptor in m['members']) {
      var pcOffset = int.parse(descriptor['pcOffset'], radix:16);
      var deoptId = descriptor['deoptId'];
      var tokenPos = descriptor['tokenPos'];
      var tryIndex = descriptor['tryIndex'];
      var kind = descriptor['kind'].trim();
      descriptors.add(
          new PcDescriptor(pcOffset, deoptId, tokenPos, tryIndex, kind));
    }
  }
}

class LocalVarDescriptor extends Observable {
  @reflectable final String name;
  @reflectable final int index;
  @reflectable final int beginPos;
  @reflectable final int endPos;
  @reflectable final int scopeId;
  @reflectable final String kind;

  LocalVarDescriptor(this.name, this.index, this.beginPos, this.endPos,
                     this.scopeId, this.kind);
}

class LocalVarDescriptors extends ServiceObject {
  @observable Class clazz;
  @observable int size;
  bool get canCache => false;
  bool get immutable => true;
  @reflectable final List<LocalVarDescriptor> descriptors =
        new ObservableList<LocalVarDescriptor>();
  LocalVarDescriptors._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _update(ObservableMap m, bool mapIsRef) {
    if (mapIsRef) {
      return;
    }
    _upgradeCollection(m, isolate);
    clazz = m['class'];
    size = m['size'];
    descriptors.clear();
    for (var descriptor in m['members']) {
      var name = descriptor['name'];
      var index = descriptor['index'];
      var beginPos = descriptor['beginPos'];
      var endPos = descriptor['endPos'];
      var scopeId = descriptor['scopeId'];
      var kind = descriptor['kind'].trim();
      descriptors.add(
          new LocalVarDescriptor(name, index, beginPos, endPos, scopeId, kind));
    }
  }
}

class TokenStream extends ServiceObject {
  @observable Class clazz;
  @observable int size;
  bool get canCache => false;
  bool get immutable => true;

  @observable String privateKey;

  TokenStream._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _update(ObservableMap m, bool mapIsRef) {
    if (mapIsRef) {
      return;
    }
    _upgradeCollection(m, isolate);
    clazz = m['class'];
    size = m['size'];
    privateKey = m['privateKey'];
  }
}

class CodeInstruction extends Observable {
  @observable final int address;
  @observable final int pcOffset;
  @observable final String machine;
  @observable final String human;
  @observable CodeInstruction jumpTarget;
  @reflectable List<PcDescriptor> descriptors =
      new ObservableList<PcDescriptor>();

  CodeInstruction(this.address, this.pcOffset, this.machine, this.human);

  @reflectable bool get isComment => address == 0;
  @reflectable bool get hasDescriptors => descriptors.length > 0;

  bool _isJumpInstruction() {
    return human.startsWith('j');
  }

  int _getJumpAddress() {
    assert(_isJumpInstruction());
    var chunks = human.split(' ');
    if (chunks.length != 2) {
      // We expect jump instructions to be of the form 'j.. address'.
      return 0;
    }
    var address = chunks[1];
    if (address.startsWith('0x')) {
      // Chop off the 0x.
      address = address.substring(2);
    }
    try {
      return int.parse(address, radix:16);
    } catch (_) {
      return 0;
    }
  }

  void _resolveJumpTarget(List<CodeInstruction> instructions) {
    if (!_isJumpInstruction()) {
      return;
    }
    int address = _getJumpAddress();
    if (address == 0) {
      return;
    }
    for (var i = 0; i < instructions.length; i++) {
      var instruction = instructions[i];
      if (instruction.address == address) {
        jumpTarget = instruction;
        return;
      }
    }
  }
}

class CodeKind {
  final _value;
  const CodeKind._internal(this._value);
  String toString() => '$_value';
  bool isSynthetic() => [Collected, Native, Tag].contains(this);
  bool isDart() => !isSynthetic();
  static CodeKind fromString(String s) {
    if (s == 'Native') {
      return Native;
    } else if (s == 'Dart') {
      return Dart;
    } else if (s == 'Collected') {
      return Collected;
    } else if (s == 'Tag') {
      return Tag;
    } else if (s == 'Stub') {
      return Stub;
    }
    Logger.root.severe("Unrecognized code kind: '$s'");
    throw new FallThroughError();
  }
  static const Collected = const CodeKind._internal('Collected');
  static const Dart = const CodeKind._internal('Dart');
  static const Native = const CodeKind._internal('Native');
  static const Stub = const CodeKind._internal('Stub');
  static const Tag = const CodeKind._internal('Tag');
}

class CodeInlineInterval {
  final int start;
  final int end;
  final List<ServiceFunction> functions = new List<ServiceFunction>();
  bool contains(int pc) => (pc >= start) && (pc < end);
  CodeInlineInterval(this.start, this.end);
}

class Code extends ServiceObject {
  @observable CodeKind kind;
  @observable ServiceObject objectPool;
  @observable ServiceFunction function;
  @observable Script script;
  @observable bool isOptimized = false;
  @reflectable int startAddress = 0;
  @reflectable int endAddress = 0;
  @reflectable final instructions = new ObservableList<CodeInstruction>();
  @observable ProfileCode profile;
  final List<CodeInlineInterval> inlineIntervals =
      new List<CodeInlineInterval>();
  final ObservableList<ServiceFunction> inlinedFunctions =
      new ObservableList<ServiceFunction>();

  bool get immutable => true;

  Code._empty(ServiceObjectOwner owner) : super._empty(owner);

  void _updateDescriptors(Script script) {
    this.script = script;
    for (var instruction in instructions) {
      for (var descriptor in instruction.descriptors) {
        descriptor.processScript(script);
      }
    }
  }

  void loadScript() {
    if (script != null) {
      // Already done.
      return;
    }
    if (kind != CodeKind.Dart){
      return;
    }
    if (function == null) {
      return;
    }
    if ((function.location == null) ||
        (function.location.script == null)) {
      // Attempt to load the function.
      function.load().then((func) {
        var script = function.location.script;
        if (script == null) {
          // Function doesn't have an associated script.
          return;
        }
        // Load the script and then update descriptors.
        script.load().then(_updateDescriptors);
      });
      return;
    }
    // Load the script and then update descriptors.
    function.location.script.load().then(_updateDescriptors);
  }

  /// Reload [this]. Returns a future which completes to [this] or an
  /// exception.
  Future<ServiceObject> reload() {
    assert(kind != null);
    if (isDartCode) {
      // We only reload Dart code.
      return super.reload();
    }
    return new Future.value(this);
  }

  void _update(ObservableMap m, bool mapIsRef) {
    name = m['name'];
    vmName = (m.containsKey('vmName') ? m['vmName'] : name);
    isOptimized = m['_optimized'];
    kind = CodeKind.fromString(m['kind']);
    if (mapIsRef) {
      return;
    }
    _loaded = true;
    startAddress = int.parse(m['_startAddress'], radix:16);
    endAddress = int.parse(m['_endAddress'], radix:16);
    function = isolate.getFromMap(m['function']);
    objectPool = isolate.getFromMap(m['_objectPool']);
    var disassembly = m['_disassembly'];
    if (disassembly != null) {
      _processDisassembly(disassembly);
    }
    var descriptors = m['_descriptors'];
    if (descriptors != null) {
      descriptors = descriptors['members'];
      _processDescriptors(descriptors);
    }
    hasDisassembly = (instructions.length != 0) && (kind == CodeKind.Dart);
    inlinedFunctions.clear();
    var inlinedFunctionsTable = m['_inlinedFunctions'];
    var inlinedIntervals = m['_inlinedIntervals'];
    if (inlinedFunctionsTable != null) {
      // Iterate and upgrade each ServiceFunction.
      for (var i = 0; i < inlinedFunctionsTable.length; i++) {
        // Upgrade each function and set it back in the list.
        var func = isolate.getFromMap(inlinedFunctionsTable[i]);
        inlinedFunctionsTable[i] = func;
        if (!inlinedFunctions.contains(func)) {
          inlinedFunctions.add(func);
        }
      }
    }
    if ((inlinedIntervals == null) || (inlinedFunctionsTable == null)) {
      // No inline information.
      inlineIntervals.clear();
      return;
    }
    _processInline(inlinedFunctionsTable, inlinedIntervals);
  }

  CodeInlineInterval findInterval(int pc) {
    for (var i = 0; i < inlineIntervals.length; i++) {
      var interval = inlineIntervals[i];
      if (interval.contains(pc)) {
        return interval;
      }
    }
    return null;
  }

  void _processInline(List<ServiceFunction> inlinedFunctionsTable,
                      List<List<int>> inlinedIntervals) {
    for (var i = 0; i < inlinedIntervals.length; i++) {
      var inlinedInterval = inlinedIntervals[i];
      var start = inlinedInterval[0] + startAddress;
      var end = inlinedInterval[1] + startAddress;
      var codeInlineInterval = new CodeInlineInterval(start, end);
      for (var i = 2; i < inlinedInterval.length - 1; i++) {
        var inline_id = inlinedInterval[i];
        if (inline_id < 0) {
          continue;
        }
        var function = inlinedFunctionsTable[inline_id];
        codeInlineInterval.functions.add(function);
      }
      inlineIntervals.add(codeInlineInterval);
    }
  }

  @observable bool hasDisassembly = false;

  void _processDisassembly(List<String> disassembly){
    assert(disassembly != null);
    instructions.clear();
    assert((disassembly.length % 3) == 0);
    for (var i = 0; i < disassembly.length; i += 3) {
      var address = 0;  // Assume code comment.
      var machine = disassembly[i + 1];
      var human = disassembly[i + 2];
      var pcOffset = 0;
      if (disassembly[i] != '') {
        // Not a code comment, extract address.
        address = int.parse(disassembly[i]);
        pcOffset = address - startAddress;
      }
      var instruction = new CodeInstruction(address, pcOffset, machine, human);
      instructions.add(instruction);
    }
    for (var instruction in instructions) {
      instruction._resolveJumpTarget(instructions);
    }
  }

  void _processDescriptor(Map d) {
    var pcOffset = int.parse(d['pcOffset'], radix:16);
    var address = startAddress + pcOffset;
    var deoptId = d['deoptId'];
    var tokenPos = d['tokenPos'];
    var tryIndex = d['tryIndex'];
    var kind = d['kind'].trim();
    for (var instruction in instructions) {
      if (instruction.address == address) {
        instruction.descriptors.add(new PcDescriptor(pcOffset,
                                                     deoptId,
                                                     tokenPos,
                                                     tryIndex,
                                                     kind));
        return;
      }
    }
    Logger.root.warning(
        'Could not find instruction with pc descriptor address: $address');
  }

  void _processDescriptors(List<Map> descriptors) {
    for (Map descriptor in descriptors) {
      _processDescriptor(descriptor);
    }
  }

  /// Returns true if [address] is contained inside [this].
  bool contains(int address) {
    return (address >= startAddress) && (address < endAddress);
  }

  @reflectable bool get isDartCode => (kind == CodeKind.Dart) ||
                                      (kind == CodeKind.Stub);

  String toString() => 'Code($kind, $name)';
}


class SocketKind {
  final _value;
  const SocketKind._internal(this._value);
  String toString() => '$_value';

  static SocketKind fromString(String s) {
    if (s == 'Listening') {
      return Listening;
    } else if (s == 'Normal') {
      return Normal;
    } else if (s == 'Pipe') {
      return Pipe;
    } else if (s == 'Internal') {
      return Internal;
    }
    Logger.root.warning('Unknown socket kind $s');
    throw new FallThroughError();
  }
  static const Listening = const SocketKind._internal('Listening');
  static const Normal = const SocketKind._internal('Normal');
  static const Pipe = const SocketKind._internal('Pipe');
  static const Internal = const SocketKind._internal('Internal');
}

/// A snapshot of statistics associated with a [Socket].
class SocketStats {
  @reflectable final int bytesRead;
  @reflectable final int bytesWritten;
  @reflectable final int readCalls;
  @reflectable final int writeCalls;
  @reflectable final int available;

  SocketStats(this.bytesRead, this.bytesWritten,
              this.readCalls, this.writeCalls,
              this.available);
}

/// A peer to a Socket in dart:io. Sockets can represent network sockets or
/// OS pipes. Each socket is owned by another ServceObject, for example,
/// a process or an HTTP server.
class Socket extends ServiceObject {
  Socket._empty(ServiceObjectOwner owner) : super._empty(owner);

  bool get canCache => true;

  ServiceObject socketOwner;

  @reflectable bool get isPipe => (kind == SocketKind.Pipe);

  @observable SocketStats latest;
  @observable SocketStats previous;

  @observable SocketKind kind;

  @observable String protocol = '';

  @observable bool readClosed = false;
  @observable bool writeClosed = false;
  @observable bool closing = false;

  /// Listening for connections.
  @observable bool listening = false;

  @observable int fd;

  @observable String localAddress;
  @observable int localPort;
  @observable String remoteAddress;
  @observable int remotePort;

  // Updates internal state from [map]. [map] can be a reference.
  void _update(ObservableMap map, bool mapIsRef) {
    name = map['name'];
    vmName = map['name'];

    kind = SocketKind.fromString(map['kind']);

    if (mapIsRef) {
      return;
    }

    _loaded = true;

    _upgradeCollection(map, isolate);

    readClosed = map['readClosed'];
    writeClosed = map['writeClosed'];
    closing = map['closing'];
    listening = map['listening'];

    protocol = map['protocol'];

    localAddress = map['localAddress'];
    localPort = map['localPort'];
    remoteAddress = map['remoteAddress'];
    remotePort = map['remotePort'];

    fd = map['fd'];
    socketOwner = map['owner'];
  }
}

class MetricSample {
  final double value;
  final DateTime time;
  MetricSample(this.value) : time = new DateTime.now();
}

class ServiceMetric extends ServiceObject {
  ServiceMetric._empty(ServiceObjectOwner owner) : super._empty(owner) {
  }

  bool get canCache => true;
  bool get immutable => false;

  @observable bool recording = false;
  MetricPoller poller;

  final ObservableList<MetricSample> samples =
      new ObservableList<MetricSample>();
  int _sampleBufferSize = 100;
  int get sampleBufferSize => _sampleBufferSize;
  set sampleBufferSize(int size) {
    _sampleBufferSize = size;
    _removeOld();
  }

  Future<ObservableMap> _fetchDirect() {
    assert(owner is Isolate);
    return isolate.invokeRpcNoUpgrade('_getIsolateMetric', { 'metricId': id });
  }


  void addSample(MetricSample sample) {
    samples.add(sample);
    _removeOld();
  }

  void _removeOld() {
    // TODO(johnmccutchan): If this becomes hot, consider using a circular
    // buffer.
    if (samples.length > _sampleBufferSize) {
      int count = samples.length - _sampleBufferSize;
      samples.removeRange(0, count);
    }
  }

  @observable String description;
  @observable double value = 0.0;
  // Only a guage has a non-null min and max.
  @observable double min;
  @observable double max;

  bool get isGauge => (min != null) && (max != null);

  void _update(ObservableMap map, bool mapIsRef) {
    name = map['name'];
    description = map['description'];
    vmName = map['name'];
    value = map['value'];
    min = map['min'];
    max = map['max'];
  }

  String toString() => "ServiceMetric($_id)";
}

class MetricPoller {
  // Metrics to be polled.
  final List<ServiceMetric> metrics = new List<ServiceMetric>();
  final Duration pollPeriod;
  Timer _pollTimer;

  MetricPoller(int milliseconds) :
      pollPeriod = new Duration(milliseconds: milliseconds) {
    start();
  }

  void start() {
    _pollTimer = new Timer.periodic(pollPeriod, _onPoll);
  }

  void cancel() {
    if (_pollTimer != null) {
      _pollTimer.cancel();
    }
    _pollTimer = null;
  }

  void _onPoll(_) {
    // Reload metrics and add a sample to each.
    for (var metric in metrics) {
      metric.reload().then((m) {
        m.addSample(new MetricSample(m.value));
      });
    }
  }
}

class Frame extends ServiceObject {
  @observable int index;
  @observable ServiceFunction function;
  @observable SourceLocation location;
  @observable Code code;
  @observable List<ServiceMap> variables = new ObservableList<ServiceMap>();

  Frame._empty(ServiceObject owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    assert(!mapIsRef);
    _loaded = true;
    _upgradeCollection(map, owner);
    this.index = map['index'];
    this.function = map['function'];
    this.location = map['location'];
    this.code = map['code'];
    this.variables = map['vars'];
  }

  String toString() => "Frame(${function.qualifiedName})";
}


class ServiceMessage extends ServiceObject {
  @observable int index;
  @observable String messageObjectId;
  @observable int size;
  @observable ServiceFunction handler;
  @observable SourceLocation location;

  ServiceMessage._empty(ServiceObject owner) : super._empty(owner);

  void _update(ObservableMap map, bool mapIsRef) {
    assert(!mapIsRef);
    _loaded = true;
    _upgradeCollection(map, owner);
    this.messageObjectId = map['messageObjectId'];
    this.index = map['index'];
    this.size = map['size'];
    this.handler = map['handler'];
    this.location = map['location'];
  }
}


// Returns true if [map] is a service map. i.e. it has the following keys:
// 'id' and a 'type'.
bool _isServiceMap(ObservableMap m) {
  return (m != null) && (m['type'] != null);
}

bool _hasRef(String type) => type.startsWith('@');
String _stripRef(String type) => (_hasRef(type) ? type.substring(1) : type);

/// Recursively upgrades all [ServiceObject]s inside [collection] which must
/// be an [ObservableMap] or an [ObservableList]. Upgraded elements will be
/// associated with [vm] and [isolate].
void _upgradeCollection(collection, ServiceObjectOwner owner) {
  if (collection is ServiceMap) {
    return;
  }
  if (collection is ObservableMap) {
    _upgradeObservableMap(collection, owner);
  } else if (collection is ObservableList) {
    _upgradeObservableList(collection, owner);
  }
}

void _upgradeObservableMap(ObservableMap map, ServiceObjectOwner owner) {
  map.forEach((k, v) {
    if ((v is ObservableMap) && _isServiceMap(v)) {
      map[k] = owner.getFromMap(v);
    } else if (v is ObservableList) {
      _upgradeObservableList(v, owner);
    } else if (v is ObservableMap) {
      _upgradeObservableMap(v, owner);
    }
  });
}

void _upgradeObservableList(ObservableList list, ServiceObjectOwner owner) {
  for (var i = 0; i < list.length; i++) {
    var v = list[i];
    if ((v is ObservableMap) && _isServiceMap(v)) {
      list[i] = owner.getFromMap(v);
    } else if (v is ObservableList) {
      _upgradeObservableList(v, owner);
    } else if (v is ObservableMap) {
      _upgradeObservableMap(v, owner);
    }
  }
}
