import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart' as vs;
import 'package:vm_service/vm_service_io.dart';

import 'dart:developer';

import 'iso_pool.dart';
import 'ui/all.dart';


void doCheck(Route<dynamic> route, Route<dynamic> previousRoute, NavigatorState navigator, {Set<String> extraCheckTargets, Set<String> filterCheckTargets}){
  String pageName = '';
  String extraWidgetName = '';
  bool isStateful = false;
  BuildContext context = navigator.context;
  final overlay = navigator.overlay;
  switch(route.runtimeType){
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
      if(route is PageRoute){
        Widget widget = route.buildPage(context, ProxyAnimation(), ProxyAnimation());
        extraWidgetName = widget.toString();
        isStateful = widget is StatefulWidget;
        widget = null;
      }
      break;
  }

  final canCheck = pageName.isNotEmpty || extraWidgetName.isNotEmpty;
  if (!canCheck) return;

  final extraTargets = extraCheckTargets ?? {};
  extraTargets.add(extraWidgetName);

  _IsoUtil().startCheck(pageName, isStateful, extraTargets: extraTargets).then((value) {
    bool needShowWater = value?.memoryInfo != _memoryInfo;
    _memoryInfo = value.memoryInfo;
    _mainIsoRef = value.mainIsoId;
    final util = OverlayUtil.getInstance();
    final controller = FutureController();
    _waterController ??= FutureController();
    util.show(
        showWidget: ScaleAniWidget(
          futureController: controller,
          child: DraggableButton(
            futureController: _waterController,
            onTap: () async{
              await controller.onCall();
              util.hide();
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (ctx) => LeakListPage(memoryInfo: _memoryInfo)))
                  .then((value) =>  util.reshow(overlay));
            },
          ),
        ),
        overlayState: overlay);
    if(needShowWater) _waterController.onCall();
  });
}

MemoryInfo _memoryInfo;
String _mainIsoRef;
FutureController _waterController;

class _IsoUtil {
  static final _IsoUtil _instance = _IsoUtil._internal();

  factory _IsoUtil() {
    return _instance;
  }

  _IsoUtil._internal();

  Future<ResultInfo> startCheck(String pageName, bool isStateful,{Set<String> extraTargets}) async {
    final leakedTargets = _memoryInfo?.leakMaps?.keys?.toSet() ?? {};
    if(extraTargets != null) leakedTargets.addAll(extraTargets);
    final result = await IsoPool()
        .start(checkMemory, CheckInfo(pageName, isStateful, leakedTargets));
    return result;
  }
}

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

  final emptyTarget = getAllocatedIns(checkInfo, allocate);

  final MemoryInfo memoryInfo = await getLeakObjects(targetClasses, vmInfo);

  filterAllocatedIns(memoryInfo, emptyTarget);

  final result = ResultInfo(memoryInfo, mainIsoRef.id);

  return result;
}

void filterAllocatedIns(MemoryInfo memoryInfo, Set<String> emptyTarget) {
  memoryInfo.leakMaps.removeWhere((key, value) => emptyTarget.contains(key) && !value.hasChildren);
}

Set<String> getAllocatedIns(
    CheckInfo checkInfo, vs.AllocationProfile allocate) {
  final leakedTargets = checkInfo.leakedTargets;
  final Set<String> emptyTarget = {};
  if (leakedTargets.isNotEmpty)
    allocate.members.forEach((mem) {
      final name = mem.classRef.name;
      if (leakedTargets.contains(name) && mem.instancesCurrent < 1) {
        emptyTarget.add(name);
      }
    });
  return emptyTarget;
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
  final pageName = commonInfo.checkInfo.pageName;
  final isStateful = commonInfo.checkInfo.isStateful;
  final leakedTargets = commonInfo.checkInfo.leakedTargets;

  List<LeakTarget> result = [];
  await Future.forEach<vs.LibraryRef>(libs, (lib) async {
    final vs.Library obj = await service.getObject(iso.id, lib.id);
    final classes = obj.classes ?? [];
    await Future.forEach<vs.ClassRef>(classes, (cla) async {
      final vs.Class obj = await service.getObject(iso.id, cla.id);
      final isState = isStateful && obj.superType.name == 'State<$pageName>';
      final isTargetPage = obj.name == pageName;
      final needCheck = leakedTargets.contains(obj.name);
      final isTarget = isState || isTargetPage || needCheck;
      if (isTarget) result.add(LeakTarget(isState, obj));
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
        await service.getInstances(iso.id, cla.id, 100);
    final leakCount = parentObj.totalCount;
    final hasParentObj = leakCount > 0;
    needRecord = hasParentObj;
    final fields = cla.fields;
    LeakInfo parentLeakInfo = LeakInfo(parentObj, cla);
    List<LeakInfo> children = [];
    parentLeakInfo.children = children;
    if (target.isStateful)
      await Future.forEach<vs.FieldRef>(fields, (field) async {
        final typeClass = field.declaredType.typeClass;
        final isBaseType = filterSet.contains(typeClass.name);
        if (isBaseType) return;
        // if (typeClass is! vs.Class) debugPrint('typeClass:$typeClass');
        final vs.Class fieldClass =
            await service.getObject(iso.id, typeClass.id);
        final vs.InstanceSet fieldIns =
            await service.getInstances(iso.id, fieldClass.id, 100);
        final hasFieldObj = fieldIns.totalCount > 0;
        if (!hasFieldObj && !hasParentObj) return;
        if (hasFieldObj) {
          needRecord = true;
          LeakInfo fieldLeakInfo = LeakInfo(fieldIns, fieldClass);
          children.add(fieldLeakInfo);
        }
      });
    if (needRecord) resultMap[cla.name] = parentLeakInfo;
  });
  return memoryInfo;
}

class RetainingInfo{
  final String targetId;
  String mainIsoRef;
  final int limit;

  RetainingInfo(this.targetId, {this.limit = 100});
}

class RetainObjInfo{
  String retainedBy;
  String retainedObj;
  int index;
  List<String> details = [];
}

Future<List<RetainObjInfo>> getRetainingPath(RetainingInfo retainingInfo) async{
  retainingInfo.mainIsoRef = _mainIsoRef;
  try{
    return await IsoPool()
        .start(_getRetainingPath, retainingInfo);
  } catch(e){
    final errorRetainObjInfo = RetainObjInfo();
    errorRetainObjInfo.index = 0;
    errorRetainObjInfo.details = [];
    errorRetainObjInfo.retainedObj = 'ERROR:  ${e.toString()}';
    errorRetainObjInfo.retainedBy = '';
    return [errorRetainObjInfo];
  }
}

Future<List<RetainObjInfo>> _getRetainingPath(RetainingInfo retainingInfo) async{
  final service = await getService();
  final isoId = retainingInfo.mainIsoRef;
  final retainPath = await service.getRetainingPath(isoId, retainingInfo.targetId, retainingInfo.limit);
  List<RetainObjInfo> result = [];
  int index = 0;
  await Future.forEach<vs.RetainingObject>(retainPath.elements, (element) async{
    final value = element.value;
    final retainObjInfo = RetainObjInfo();
    result.add(retainObjInfo);
    retainObjInfo.index = index;
    switch(value.runtimeType){
      case vs.ContextRef:
        final v = value as vs.ContextRef;
        final length = v.length;
        final lengthString = length == null ? '' : '($length)';
        retainObjInfo.retainedBy = element.parentField ?? 'offset';
        retainObjInfo.retainedObj = 'Context' + lengthString;
        break;
      case vs.InstanceRef:
        final v = value as vs.InstanceRef;
        final length = v.length;
        final lengthString = length == null ? '' : '($length)';
        retainObjInfo.retainedBy = element.parentField ?? 'offset';
        retainObjInfo.retainedObj = v.classRef.name + lengthString;
        break;
      default:
        debugPrint('UnCatch Value Type :$value');
        break;
    }

    final obj =  await service.getObject(isoId, value.id);
    switch(obj.runtimeType){
      case vs.Context:
        final o = obj as vs.Context;
        for (var i = 0; i < o.variables.length; ++i) {
          var element = o.variables[i];
          final v = element.value;
          if(v is vs.InstanceRef){
            retainObjInfo.details.add('${v.classRef.name}');
          } else if(v is vs.ContextRef){
            final length = v.length;
            final lengthString = length == null ? '' : '($length)';
            retainObjInfo.details.add('Context' + lengthString);
          } else debugPrint('UnCatch Variables Type :$v');
          if(i >= 100){
            retainObjInfo.details.add('MORE THAN 100, HIDE OTHERS');
            return;
          }
        }
        break;
      case vs.Instance:
        final o = obj as vs.Instance;
        bool isClosure = o.kind == 'Closure';
        if(isClosure){
          final closure = o.closureFunction;
          final vs.Func func = await service.getObject(isoId, closure?.id ?? '');
          final location = func.location;
          final vs.Script script = await service.getObject(isoId, location.script.id);
          final closureName = func.code.name.replaceAll('[Unoptimized]', '');
          final source = script.source.substring(location.tokenPos, location.endTokenPos);
          retainObjInfo.details.add('function = $closureName');
          retainObjInfo.details.add('code :');
          retainObjInfo.details.add(source);
        } else {
          final fields = o.fields;
          fields?.forEach((field) {
            final decl = field.decl;
            final finalString = decl.isFinal ? 'final ' : '';

            final typeString = (decl.declaredType.typeClass?.name ?? decl.declaredType.classRef.name) + ' ';
            final nameString = decl.name.toString() + ' ';
            String valueString = '';
            if(field.value == null) valueString = '= null';
            else {
              if(field.value is vs.InstanceRef){
                final value = field.value as vs.InstanceRef;
                valueString = value.valueAsString ?? value.classRef.name;
                valueString = '= $valueString';
              } else valueString = field.value.runtimeType.toString();
            }
            final showText = finalString + typeString + nameString + valueString;
            retainObjInfo.details.add(showText);
          });

          final elements = o.elements;
          for (var i = 0; i < (elements?.length ?? 0); ++i) {
            var element = elements[i];
            if(element == null) break;
            if(element is vs.InstanceRef){
              final name = element.classRef.name;
              retainObjInfo.details.add(name);
            } else retainObjInfo.details.add(element.runtimeType.toString());
          }
        }
        break;
      default:
        debugPrint('UnCatch Object Type :$obj');
        break;
    }
    index++;
  });
  return result;
}

Future<vs.InboundReferences> getInboundReferences(String targetId, {int limit = 100}) async{
  final service = await getService();
  final isoId = _mainIsoRef;
  return service.getInboundReferences(isoId, targetId, limit);
}


class MemoryInfo {
  final Map<String, LeakInfo> leakMaps;

  MemoryInfo(this.leakMaps);

  @override
  bool operator ==(Object other) {
    if(other is! MemoryInfo) return false;
    // ignore: test_types_in_equals
    final o = other as MemoryInfo;
    if(leakMaps?.length != o?.leakMaps?.length) return false;
    final set = leakMaps.keys.toSet();
    final oSet = o.leakMaps.keys.toSet();
    if(!set.containsAll(oSet)) return false;
    bool result = true;
    leakMaps.forEach((key, value) {
      final l = value.instanceObj.instances.length;
      final oL = o.leakMaps[key].instanceObj.instances.length;
      if(l != oL) {
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
  List<LeakInfo> children;

  LeakInfo(this.instanceObj, this.claObj, {this.children});

  bool get hasInstance => (instanceObj?.totalCount ?? 0) > 0;

  bool get hasChildren => children?.isNotEmpty ?? false;
}

class CheckInfo {
  String pageName;
  bool isStateful;
  Set<String> leakedTargets;

  CheckInfo(this.pageName, this.isStateful, this.leakedTargets);
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

class CommonInfo{
  final CheckInfo checkInfo;
  final VmInfo vmInfo;

  CommonInfo(this.checkInfo, this.vmInfo);
}

class ResultInfo{
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
