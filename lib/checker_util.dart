import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart' as vs;
import 'package:vm_service/vm_service_io.dart';

import 'dart:developer';

import 'iso_pool.dart';
import 'ui/all.dart';

Future doCheck(Route<dynamic> route, Route<dynamic> previousRoute,
    NavigatorState navigator,
    {Set<TargetWidget> extraCheckTargets,
    Set<TargetWidget> filterCheckTargets}) async {
  if (!canCheckMemory) return;
  String pageName = '';
  String extraWidgetName = '';
  bool isStateful = false;
  BuildContext context = navigator.context;
  final overlay = navigator.overlay;
  switch (route.runtimeType) {
    case MaterialPageRoute:
      final r = route as MaterialPageRoute;
      Widget widget = r.builder.call(context);
      pageName = widget.toString();
      isStateful = widget is StatefulWidget;
      widget = null;
      break;
    case CupertinoPageRoute:
      final r = route as MaterialPageRoute;
      Widget widget = r.builder.call(context);
      pageName = widget.toString();
      isStateful = widget is StatefulWidget;
      widget = null;
      break;
    default:
      if (route is PageRoute) {
        Widget widget =
            route.buildPage(context, ProxyAnimation(), ProxyAnimation());
        extraWidgetName = widget.toString();
        isStateful = widget is StatefulWidget;
        widget = null;
      }
      break;
  }

  final canCheck = pageName.isNotEmpty || extraWidgetName.isNotEmpty;
  if (!canCheck) return;
  final checkName = pageName.isEmpty ? extraWidgetName : pageName;

  final extraTargets = extraCheckTargets ?? {};
  extraTargets.add(TargetWidget(checkName, isStateful: isStateful));

  final result = await IsoUtil()
      .startCheckWithNotify(pageName, isStateful, extraTargets: extraTargets);
  final util = OverlayUtil.getInstance();
  final controller = FutureController();
  _waterController ??= FutureParamController<CompareType>();
  util.show(
      showWidget: ScaleAniWidget(
        futureController: controller,
        child: DraggableButton<CompareType>(
          futureController: _waterController,
          onTap: () async {
            await controller.onCall();
            util.hide();
            canCheckMemory = false;
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (ctx) => LeakListPage()))
                .then((value) {
              util.reshow(overlay);
            });
          },
        ),
      ),
      overlayState: overlay);
  _waterController.onCall(result.compareType);
}

String _mainIsoRef;
FutureParamController<CompareType> _waterController;
TargetInfo _targetInfo;
bool canCheckMemory = true;

class IsoUtil {
  static final IsoUtil _instance = IsoUtil._internal();

  factory IsoUtil() {
    return _instance;
  }

  IsoUtil._internal();

  Future<ResultInfo> startCheck() async {
    final result =
        await IsoPool().start(checkMemory, CheckInfo(_targetInfo._targetMap));
    _mainIsoRef = result.mainIsoId;
    return result;
  }

  Future<NotifyResult> startCheckWithNotify(String pageName, bool isStateful,
      {Set<TargetWidget> extraTargets}) async {
    final Map<String, TargetWidget> targetMap = {};
    extraTargets.forEach((element) {
      targetMap[element.targetName] = element;
    });
    if (_targetInfo == null) _targetInfo = TargetInfo(targetMap, {});
    _targetInfo._targetMap.forEach((key, value) {
      final oldEle = _targetInfo._targetMap[key];
      if (oldEle != null) targetMap[key] = oldEle;
    });
    final result = await IsoPool().start(
        checkWithNotify, CheckNotifyInfo(targetMap, _targetInfo._compareMap));
    result.targetMap.forEach((key, value) {
      _targetInfo._targetMap[key] = value;
    });
    result.compareMap.forEach((key, value) {
      _targetInfo._compareMap[key] = value;
    });
    return result;
  }
}

enum CompareType { less, same, more, mix }

Future<ResultInfo> checkMemory(CheckInfo checkInfo) async {
  final vmService = await getService();
  final vm = await vmService.getVM();

  final isoGroup = vm.isolates;
  final mainIsoRef = await traverseIsolates(isoGroup);
  if (mainIsoRef == null) throw Exception('Error: not fount main isolate');

  VmInfo vmInfo = VmInfo();
  vmInfo.setValue(
    service: vmService,
    vm: vm,
    mainIsoRef: mainIsoRef,
  );
  CommonInfo commonInfo = CommonInfo(checkInfo, vmInfo);

  await getMainIso(vmInfo);

  final libs = await getTargetLibs(commonInfo);
  final targetClasses = await traverseLibs(libs, commonInfo);

  final allocate = await startAllocate(vmInfo);

  getAllocatedIns(checkInfo, allocate);

  final MemoryInfo memoryInfo = await getLeakObjects(targetClasses, vmInfo);

  final result = ResultInfo(memoryInfo, mainIsoRef.id);

  return result;
}

Future<NotifyResult> checkWithNotify(CheckNotifyInfo checkNotifyInfo) async {
  final vmService = await getService();
  final vm = await vmService.getVM();

  final isoGroup = vm.isolates;
  final mainIsoRef = await traverseIsolates(isoGroup);
  if (mainIsoRef == null) throw Exception('Error: not fount main isolate');

  final allocationProfile =
      await vmService.getAllocationProfile(mainIsoRef.id, gc: true);
  final Map<String, TargetWidget> targetMap = Map.of(checkNotifyInfo.targetMap);
  final Map<String, TargetWidget> compareMap =
      Map.of(checkNotifyInfo.compareMap);
  final stateSet = targetMap.keys.map((e) => '_${e}State').toSet();
  CompareType compareType = CompareType.same;
  int sum = 0;
  for (final mem in allocationProfile.members) {
    final name = mem.classRef.name;
    final count = mem.instancesCurrent;
    final isState = stateSet.contains(name);
    final isTarget = targetMap[name] != null;
    if (isState) {
      final cur = compareMap[name];
      sum += (count - (cur?.existCount ?? 0));
      if (cur?.existCount != count) {
        final tw = TargetWidget(name,
            isStateful: cur?.isStateful ?? true, existCount: count);
        compareMap[name] = tw;
      }
    }
    if (isTarget) {
      final cur = targetMap[name];
      sum += (count - cur.existCount);
      if (cur.existCount != count) {
        final tw = TargetWidget(cur.targetName,
            isStateful: cur.isStateful, existCount: count);
        targetMap[name] = tw;
      }
      compareMap[name] = targetMap[name];
    }
  }
  if (sum > 0)
    compareType = CompareType.more;
  else if (sum < 0) compareType = CompareType.less;
  return NotifyResult(compareType, targetMap, compareMap);
}

Map<String, TargetWidget> getAllocatedIns(
    CheckInfo checkInfo, vs.AllocationProfile allocate) {
  final leakedTargets = checkInfo.targetMap;
  final Map<String, TargetWidget> resultMap = {};
  if (leakedTargets.isNotEmpty)
    allocate.members.forEach((mem) {
      final name = mem.classRef.name;
      final count = mem.instancesCurrent;
      final cur = leakedTargets[name];
      if (cur != null && count > 0) {
        resultMap[name] = TargetWidget(cur.targetName,
            isStateful: cur.isStateful, existCount: count);
      }
    });
  return resultMap;
}

Future<vs.VmService> getService() async {
  final info = await Service.getInfo();
  final serverUri = info.serverUri;
  final url = convertToWebSocketUrl(serviceProtocolUrl: serverUri);
  final service = await vmServiceConnectUri(url.toString());
  return service;
}

Future<vs.IsolateRef> traverseIsolates(List<vs.IsolateRef> isolates) async {
  for (var iso in isolates) {
    if (iso.name == 'main') return iso;
  }
  return null;
}

Future<vs.Isolate> getMainIso(VmInfo vmInfo) async {
  final isoInfo = vmInfo.mainIsoRef;
  final service = vmInfo.service;
  final curIso = await service.getIsolate(isoInfo.id);
  vmInfo.setValue(mainIso: curIso);
  return curIso;
}

Future<List<vs.LibraryRef>> getTargetLibs(CommonInfo commonInfo) async {
  final curIso = commonInfo.vmInfo.mainIso;
  final rootUrl = curIso.rootLib.uri.toString();
  final packageName = rootUrl.substring(0, rootUrl.indexOf('/'));
  commonInfo.vmInfo.setValue(packageName: packageName);
  final libs = curIso.libraries;
  final List<vs.LibraryRef> packageLibs = [];
  libs.forEach((lib) {
    final url = lib.uri;
    if (url.contains(packageName)) packageLibs.add(lib);
  });
  return packageLibs;
}

Future<List<LeakTarget>> traverseLibs(
    List<vs.LibraryRef> libs, CommonInfo commonInfo) async {
  final service = commonInfo.vmInfo.service;
  final iso = commonInfo.vmInfo.mainIso;
  final leakedTargets = commonInfo.checkInfo.targetMap;

  final stateSet = leakedTargets.keys.map((e) => 'State<$e>').toSet();

  List<LeakTarget> result = [];
  await Future.forEach<vs.LibraryRef>(libs, (lib) async {
    final vs.Library obj = await service.getObject(iso.id, lib.id);
    final classes = obj.classes ?? [];
    await Future.forEach<vs.ClassRef>(classes, (cla) async {
      final vs.Class obj = await service.getObject(iso.id, cla.id);
      final curWidget = leakedTargets[obj.name];
      final needCheck = curWidget != null;
      final isState = stateSet.contains(obj.superType.name);
      final isTargetPage = obj.name == curWidget?.targetName;
      final isTarget = isState || isTargetPage || needCheck;
      LeakTarget tar = LeakTarget(isState, obj);
      if (isState && obj.subclasses.isNotEmpty) {
        final subClass = obj.subclasses.first;
        final tarClass = await service.getObject(iso.id, subClass.id);
        tar = LeakTarget(isState, tarClass);
      }
      if (isTarget) result.add(tar);
    });
  });
  return result;
}

Future<vs.AllocationProfile> startAllocate(VmInfo vmInfo) async {
  final service = vmInfo.service;
  final iso = vmInfo.mainIso;
  return await service.getAllocationProfile(iso.id, gc: true);
}

Future<MemoryInfo> getLeakObjects(
    List<LeakTarget> targets, VmInfo vmInfo) async {
  final service = vmInfo.service;
  final iso = vmInfo.mainIso;
  final Map<String, LeakInfo> resultMap = {};
  final memoryInfo = MemoryInfo(resultMap);
  await Future.forEach<LeakTarget>(targets, (target) async {
    bool needRecord = false;
    final cla = target.targetClass;
    final vs.InstanceSet parentObj =
        await service.getInstances(iso.id, cla.id, 1);
    final leakCount = parentObj.totalCount;
    final hasParentObj = leakCount > 0;
    needRecord = hasParentObj;
    LeakInfo parentLeakInfo = LeakInfo(parentObj, cla);
    if (needRecord) resultMap[cla.name] = parentLeakInfo;
  });
  return memoryInfo;
}

Future<vs.InstanceSet> getInstances(ObjectInfo objectInfo) async {
  objectInfo.mainIsoRef = _mainIsoRef;
  return await IsoPool().start(_getInstances, objectInfo);
}

Future<vs.InstanceSet> _getInstances(ObjectInfo objectInfo) async {
  final service = await getService();
  final isoId = objectInfo.mainIsoRef;
  return await service.getInstances(
      isoId, objectInfo.targetId, objectInfo.limit);
}

class ObjectInfo {
  final String targetId;
  String mainIsoRef;
  final int limit;

  ObjectInfo(this.targetId, {this.limit = 1});
}

class RetainingObjInfo {
  final vs.RetainingObject retainingObject;
  String mainIsoRef;
  RetainingObjInfo(this.retainingObject);
}

class AnalyzeObjectInfo {
  final vs.Obj obj;
  String mainIsoRef;
  AnalyzeObjectInfo(this.obj);
}

Future<vs.Obj> getTargetObj(ObjectInfo objectInfo) async {
  objectInfo.mainIsoRef = _mainIsoRef;
  return await IsoPool().start(_getTargetObj, objectInfo);
}

Future<vs.Obj> _getTargetObj(ObjectInfo objectInfo) async {
  final service = await getService();
  final isoId = objectInfo.mainIsoRef;
  final result = await service.getObject(isoId, objectInfo.targetId);
  return result;
}

Future<vs.RetainingPath> getRetainingPath(ObjectInfo retainingInfo) async {
  retainingInfo.mainIsoRef = _mainIsoRef;
  return await IsoPool().start(_getRetainingPath, retainingInfo);
}

Future<vs.RetainingPath> _getRetainingPath(ObjectInfo retainingInfo) async {
  final service = await getService();
  final isoId = retainingInfo.mainIsoRef;
  return await service.getRetainingPath(
      isoId, retainingInfo.targetId, retainingInfo.limit);
}

Future<vs.Obj> transRetainInfo(RetainingObjInfo retainingObjInfo) async {
  retainingObjInfo.mainIsoRef = _mainIsoRef;
  return await IsoPool().start(_transformRetainObj, retainingObjInfo);
}

Future<vs.Obj> _transformRetainObj(RetainingObjInfo retainingObjInfo) async {
  final service = await getService();
  final isoId = retainingObjInfo.mainIsoRef;
  final retainObj = retainingObjInfo.retainingObject;
  return await service.getObject(isoId, retainObj.value.id);
}

Future<vs.InboundReferences> getInboundReferences(String targetId,
    {int limit = 100}) async {
  final service = await getService();
  final isoId = _mainIsoRef;
  return service.getInboundReferences(isoId, targetId, limit);
}

Future<DetailInfo> analyzeObjInfo(AnalyzeObjectInfo obj) async {
  obj.mainIsoRef = _mainIsoRef;
  return await IsoPool().start(_analyzeObjInfo, obj);
}

Future<DetailInfo> _analyzeObjInfo(AnalyzeObjectInfo objectInfo) async {
  final isoId = objectInfo.mainIsoRef;
  final obj = objectInfo.obj;
  DetailInfo detailInfo = DetailInfo(obj.id);
  switch (obj.runtimeType) {
    case vs.Context:
      final o = obj as vs.Context;
      for (var i = 0; i < o.variables.length; ++i) {
        var element = o.variables[i];
        final v = element.value;
        final dlInfo = DetailInfo(v.id);
        final List<SpanInfo> spanInfoList = [];
        if (v is vs.InstanceRef) {
          final spInfo = SpanInfo(v.classRef.name, blueStyle);
          spanInfoList.add(spInfo);
        } else if (v is vs.ContextRef) {
          final length = v.length;
          final lengthString = length == null ? '' : '($length)';
          final spInfo = SpanInfo('Context' + lengthString, blueStyle);
          spanInfoList.add(spInfo);
        } else {
          final errorText = 'UnCatch Variables Type :$v';
          final spInfo = SpanInfo(errorText, errorStyle);
          spanInfoList.add(spInfo);
        }
        detailInfo.children.add(SpanWithDetail(spanInfoList, dlInfo));
        if (i >= 10) {
          final spInfo = SpanInfo('Only support to show 10 items', errorStyle);
          spanInfoList.add(spInfo);
          break;
        }
      }
      break;
    case vs.Instance:
      final o = obj as vs.Instance;
      bool isClosure = o.kind == 'Closure';
      if (isClosure) {
        final closure = o.closureFunction;
        final dlInfo = DetailInfo(closure.id);
        final List<SpanInfo> spanInfoList = [];
        spanInfoList.add(SpanInfo('closure = ${closure.name}', blueStyle));
        detailInfo.children.add(SpanWithDetail(spanInfoList, dlInfo));
      } else {
        final fields = o.fields;
        fields?.forEach((field) {
          DetailInfo dlInfo = DetailInfo(null);
          final List<SpanInfo> spanInfoList = [];
          final dec = field.decl;
          final finalString = dec.isFinal ? 'final ' : '';

          final typeString = (dec.declaredType.typeClass?.name ??
                  dec.declaredType.classRef.name) +
              ' ';
          final nameString = dec.name.toString() + ' ';
          String valueString = '';
          if (field.value == null) {
            valueString = '= null';
          } else {
            if (field.value is vs.InstanceRef) {
              final value = field.value as vs.InstanceRef;
              valueString = value.valueAsString ?? value.classRef.name;
              valueString = '= $valueString';
              if (!filterSet.contains(value.kind))
                dlInfo = DetailInfo(value.id);
            } else
              valueString = field.value.runtimeType.toString();
          }
          spanInfoList.add(SpanInfo(finalString, defaultStyle));
          spanInfoList.add(SpanInfo(typeString, defaultStyle));
          spanInfoList.add(SpanInfo(nameString, defaultStyle));
          spanInfoList.add(SpanInfo(valueString, blueStyle));
          detailInfo.children.add(SpanWithDetail(spanInfoList, dlInfo));
        });

        final elements = o.elements;
        for (var i = 0; i < (elements?.length ?? 0); ++i) {
          final List<SpanInfo> spanInfoList = [];
          DetailInfo dlInfo = DetailInfo(null);
          var element = elements[i];
          if (element == null) break;
          if (element is vs.InstanceRef) {
            final name = element.classRef.name;
            spanInfoList.add(SpanInfo(name, defaultStyle));
            dlInfo = DetailInfo(element.id);
          } else
            spanInfoList
                .add(SpanInfo(element.runtimeType.toString(), errorStyle));
          detailInfo.children.add(SpanWithDetail(spanInfoList, dlInfo));
          if (i >= 10) {
            spanInfoList
                .add(SpanInfo('Only support to show 10 items', errorStyle));
            break;
          }
        }
      }

      break;
    case vs.Func:
      final func = obj as vs.Func;
      final dlInfo = DetailInfo(null);
      final List<SpanInfo> spanInfoList = [];
      final service = await getService();
      final location = func.location;
      final vs.Script script =
          await service.getObject(isoId, location.script.id);
      final closureName = func.code.name.replaceAll('[Unoptimized]', '');
      final source =
          script.source.substring(location.tokenPos, location.endTokenPos);
      spanInfoList.add(SpanInfo('function = $closureName', defaultStyle));
      spanInfoList.add(SpanInfo('code :', blueStyle));
      spanInfoList.add(SpanInfo(source, defaultStyle));
      detailInfo.children.add(SpanWithDetail(spanInfoList, dlInfo));
      break;
    default:
      final errorText = 'UnCatch Object Type :${obj.toString()}';
      debugPrint(errorText);
      detailInfo.children.add(
          SpanWithDetail([SpanInfo(errorText, errorStyle)], DetailInfo(null)));
      break;
  }
  return detailInfo;
}

class MemoryInfo {
  final Map<String, LeakInfo> leakMaps;

  MemoryInfo(this.leakMaps);

  @override
  bool operator ==(Object other) {
    if (other is! MemoryInfo) return false;
    // ignore: test_types_in_equals
    final o = other as MemoryInfo;
    if (leakMaps?.length != o?.leakMaps?.length) return false;
    final set = leakMaps.keys.toSet();
    final oSet = o.leakMaps.keys.toSet();
    if (!set.containsAll(oSet)) return false;
    bool result = true;
    leakMaps.forEach((key, value) {
      final l = value.instanceObj.instances.length;
      final oL = o.leakMaps[key].instanceObj.instances.length;
      if (l != oL) {
        result = false;
        return;
      }
    });
    return result;
  }

  @override
  int get hashCode => super.hashCode;
}

class LeakInfo {
  final vs.InstanceSet instanceObj;
  final vs.Class claObj;

  LeakInfo(this.instanceObj, this.claObj);

  bool get hasInstance => (instanceObj?.totalCount ?? 0) > 0;
}

class CheckInfo {
  final Map<String, TargetWidget> targetMap;

  CheckInfo(this.targetMap);
}

class CheckNotifyInfo {
  final Map<String, TargetWidget> targetMap;
  final Map<String, TargetWidget> compareMap;

  CheckNotifyInfo(this.targetMap, this.compareMap);
}

class NotifyResult {
  final CompareType compareType;
  final Map<String, TargetWidget> targetMap;
  final Map<String, TargetWidget> compareMap;

  NotifyResult(this.compareType, this.targetMap, this.compareMap);
}

class TargetWidget {
  final String targetName;
  final bool isStateful;
  final int existCount;

  TargetWidget(this.targetName, {this.isStateful = false, this.existCount = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetWidget &&
          runtimeType == other.runtimeType &&
          targetName == other.targetName &&
          isStateful == other.isStateful &&
          existCount == other.existCount;

  @override
  int get hashCode =>
      targetName.hashCode ^ isStateful.hashCode ^ existCount.hashCode;
}

class TargetInfo {
  final Map<String, TargetWidget> _targetMap;
  final Map<String, TargetWidget> _compareMap;

  TargetInfo(this._targetMap, this._compareMap);
}

class LeakTarget {
  final bool isStateful;
  final vs.Class targetClass;

  LeakTarget(this.isStateful, this.targetClass);
}

final filterSet = {
  'String',
  'List',
  'Map',
  'HashMap',
  'int',
  'Int',
  'double',
  'float',
  'long',
  'num',
  'bool',
  'Set',
  'Runes',
  'Symbole',
  'Uint8ClampedList',
  'Uint8List',
  'Uint16List',
  'Uint32List',
  'Uint64List',
  'Int8List',
  'Int16List',
  'Int32List',
  'Int64List',
  'Float32List',
  'Float64List',
  'Int32x4List',
  'Float32x4List',
  'Float64x2List',
};

class CommonInfo {
  final CheckInfo checkInfo;
  final VmInfo vmInfo;

  CommonInfo(this.checkInfo, this.vmInfo);
}

class ResultInfo {
  final MemoryInfo memoryInfo;
  final String mainIsoId;

  ResultInfo(this.memoryInfo, this.mainIsoId);
}

class VmInfo {
  String packageName;

  vs.VmService service;
  vs.VM vm;
  vs.IsolateRef mainIsoRef;
  vs.Isolate mainIso;

  void clear() {
    service = null;
    vm = null;
    mainIsoRef = null;
    mainIso = null;
  }

  void setValue({
    vs.VmService service,
    vs.VM vm,
    vs.IsolateRef mainIsoRef,
    vs.Isolate mainIso,
    String packageName,
  }) {
    if (service != null) this.service = service;
    if (vm != null) this.vm = vm;
    if (mainIsoRef != null) this.mainIsoRef = mainIsoRef;
    if (mainIso != null) this.mainIso = mainIso;
    if (packageName != null) this.packageName = packageName;
  }
}
