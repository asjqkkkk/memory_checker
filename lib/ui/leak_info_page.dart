import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' as vs;

import '../checker_util.dart';
import 'cus_expansionTile.dart';

class LeakInfoPage extends StatefulWidget {
  final LeakInfo leakInfo;
  final vs.ObjRef objRef;

  const LeakInfoPage({Key key, this.leakInfo, this.objRef}) : super(key: key);

  @override
  _LeakInfoPageState createState() => _LeakInfoPageState();
}

class _LeakInfoPageState extends State<LeakInfoPage>
    with TickerProviderStateMixin {
  vs.RetainingPath _retainingPath;
  vs.InboundReferences _inboundReferences;

  final int tabLength = 2;

  @override
  void initState() {
    final targetId = widget.objRef.id;
    getRetainingPath(ObjectInfo(targetId, limit: 100)).then((value) {
      this._retainingPath = value;
      refresh();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.leakInfo.claObj.name;
    return DefaultTabController(
      length: tabLength,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Container(
                child: Text('RetainingPath'),
                margin: EdgeInsets.all(4),
              ),
              Container(
                child: Text('InboundReferences'),
                margin: EdgeInsets.all(4),
              ),
            ],
          ),
          title: Text(name),
        ),
        body: TabBarView(
          children: [
            buildRetainWidget(),
            buildInboundRefWidget(),
          ],
        ),
      ),
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Widget buildRetainWidget() {
    if (_retainingPath == null)
      return Center(
        child: CircularProgressIndicator(),
      );

    return ListView.builder(
      itemBuilder: (ctx, index) {
        return buildItem(index);
      },
      itemCount: _retainingPath.elements.length,
    );
  }

  Widget buildItem(int index) {
    final curEle = _retainingPath.elements[index];

    final cur = transformRetainObj(curEle);
    List<SpanInfo> spans = [];
    final style = Theme.of(context).textTheme.bodyText1.copyWith(fontSize: 16);

    if (index != 0) {
      spans.add(SpanInfo('retained by ', style));
      spans.add(SpanInfo(
          cur.retainedBy, style.copyWith(fontWeight: FontWeight.bold)));
      spans.add(SpanInfo(' of ', style));
    }
    spans.add(SpanInfo(cur.retainedObj, style.copyWith(color: Colors.blue)));

    return CusExpansionTile(
      title: buildTitle(spans),
      childrenPadding: EdgeInsets.zero,
      dynamicChildren: () => [
        Container(
          padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
          alignment: Alignment.topLeft,
          child: buildFutureBuilder(getRetainObjWidget(curEle)),
        )
      ],
    );
  }

  Widget buildFutureBuilder<T>(Future<T> future) {
    return FutureBuilder(
      builder: (ctx, snapshot) {
        if (snapshot.hasData) return snapshot.data;
        return Center(
          child: Container(
            width: 20,
            height: 20,
            margin: EdgeInsets.all(5),
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        );
      },
      future: future,
    );
  }

  Future<Widget> getRetainObjWidget(vs.RetainingObject retainingObject) async {
    final obj = await transRetainInfo(RetainingObjInfo(retainingObject));
    return await getWidgetByObj(obj);
  }

  Future<Widget> getWidgetByObj(vs.Obj obj) async {
    final detailInfo = await analyzeObjInfo(AnalyzeObjectInfo(obj));
    final children = detailInfo.children;
    if(children.isEmpty) return Center(child: Text('There is no more info.', style: errorStyle,));
    return Column(
      children: List.generate(children.length, (index) {
        final cur = children[index];
        final targetId = cur.detailInfo?.targetId;
        final hasTarget = targetId != null;
        return hasTarget ? CusExpansionTile(
          title: buildTitle(cur.spanInfoList),
          childrenPadding: EdgeInsets.zero,
          dynamicChildren: () => [
            Container(
              padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
              alignment: Alignment.topLeft,
              child: buildFutureBuilder(getTargetObjWidget(targetId)),
            )
          ],
        ) : ListTile(title: buildTitle(cur.spanInfoList),);
      }),
    );
  }

  Future<Widget> getTargetObjWidget(String targetId) async{
    final obj = await getTargetObj(ObjectInfo(targetId));
    return await getWidgetByObj(obj);
  }

  Widget buildTitle(List<SpanInfo> spans) {
    return RichText(
        text: TextSpan(
            children: List.generate(spans.length, (index) {
      final span = spans[index];
      return TextSpan(
        text: span.text,
        style: span.style,
      );
    })));
  }

  Widget buildChildren(List<String> details, TextStyle style) {
    return SelectableText.rich(TextSpan(
        children: List.generate(details.length, (index) {
      final detail = details[index];
      return TextSpan(
        text: '$detail\n\n',
        style: style,
      );
    })));
  }

  Widget buildInboundRefWidget() {
    if (_inboundReferences == null)
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(
              size: 20,
            ),
            SizedBox(
              width: 4,
            ),
            Text(
              'To Be Continued...',
              style: TextStyle(fontSize: 24),
            ),
          ],
        ),
      );
    final elements = _inboundReferences.references;
    return ListView.builder(
      itemBuilder: (ctx, index) {
        final cur = elements[index];
        return Container(
          margin: EdgeInsets.all(10),
          child: Text(cur.toString()),
        );
      },
      itemCount: elements.length,
    );
  }
}

RetainShowInfo transformRetainObj(vs.RetainingObject retainingObject) {
  final value = retainingObject.value;
  final retainObjInfo = RetainShowInfo();
  switch (value.runtimeType) {
    case vs.ContextRef:
      final v = value as vs.ContextRef;
      final length = v.length;
      final lengthString = length == null ? '' : '($length)';
      retainObjInfo.retainedBy = retainingObject.parentField ?? 'offset';
      retainObjInfo.retainedObj = 'Context' + lengthString;
      break;
    case vs.InstanceRef:
      final v = value as vs.InstanceRef;
      final length = v.length;
      final lengthString = length == null ? '' : '($length)';
      retainObjInfo.retainedBy = retainingObject.parentField ?? 'offset';
      retainObjInfo.retainedObj = v.classRef.name + lengthString;
      break;
    default:
      final printData = 'UnCatch Value Type :$value';
      retainObjInfo.retainedObj = printData;
      debugPrint(printData);
      break;
  }
  return retainObjInfo;
}

class RetainShowInfo {
  String retainedBy;
  String retainedObj;
}

class SpanInfo {
  final String text;
  final TextStyle style;

  SpanInfo(this.text, this.style);
}

const defaultStyle = TextStyle(color: Colors.black);
const blueStyle = TextStyle(color: Colors.blue);
const errorStyle = TextStyle(color: Colors.red);

class DetailInfo {
  final String targetId;
  List<SpanWithDetail> children = [];

  DetailInfo(this.targetId);
}

class SpanWithDetail {
  final List<SpanInfo> spanInfoList;
  final DetailInfo detailInfo;

  SpanWithDetail(this.spanInfoList, this.detailInfo);
}
