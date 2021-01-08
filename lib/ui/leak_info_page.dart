import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' as vs;

import '../checker_util.dart';

class LeakInsList extends StatelessWidget {
  final LeakInfo leakInfo;

  const LeakInsList({Key key, this.leakInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = leakInfo.claObj.name;
    final objList = leakInfo.instanceObj.instances;
    return Scaffold(
      appBar: AppBar(
        title: Text('$name-List'),
      ),
      body: ListView.builder(
        itemBuilder: (ctx, index) {
          final obj = objList[index];
          return ListTile(
            title: Text(name),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(new MaterialPageRoute(
                  builder: (ctx) => LeakInfoPage(
                        leakInfo: leakInfo,
                        objRef: obj,
                      )));
            },
          );
        },
        itemCount: objList.length,
      ),
    );
  }
}

class LeakInfoPage extends StatefulWidget {
  final LeakInfo leakInfo;
  final vs.ObjRef objRef;

  const LeakInfoPage({Key key, this.leakInfo, this.objRef}) : super(key: key);

  @override
  _LeakInfoPageState createState() => _LeakInfoPageState();
}

class _LeakInfoPageState extends State<LeakInfoPage>
    with TickerProviderStateMixin {
  List<RetainObjInfo> _retainingPath;
  vs.InboundReferences _inboundReferences;

  final int tabLength = 2;

  @override
  void initState() {
    final targetId = widget.objRef.id;
    getRetainingPath(RetainingInfo(targetId)).then((value) {
      this._retainingPath = value;
      refresh();
    });
    // getInboundReferences(targetId).then((value) {
    //   this._inboundReferences = value;
    //   refresh();
    // });
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
              Container(child: Text('RetainingPath'), margin: EdgeInsets.all(4),),
              Container(child: Text('InboundReferences'), margin: EdgeInsets.all(4),),
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
        final cur = _retainingPath[index];
        final details = cur.details;
        List<TextWithStyle> spans = [];
        final style = Theme.of(context).textTheme.bodyText1.copyWith(fontSize: 16);

        if (index != 0) {
          spans.add(TextWithStyle('retained by ', style));
          spans.add(TextWithStyle(
              cur.retainedBy, style.copyWith(fontWeight: FontWeight.bold)));
          spans.add(TextWithStyle(' of ', style));
        }
        spans.add(
            TextWithStyle(cur.retainedObj, style.copyWith(color: Colors.blue)));

        return ExpansionTile(
          title: buildTitle(spans),
          childrenPadding: EdgeInsets.zero,
          children: [Container(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            alignment: Alignment.topLeft,
            child: buildChildren(details, style.copyWith(fontSize: 14)),
          )],
        );
      },
      itemCount: _retainingPath.length,
    );
  }

  Widget buildTitle(List<TextWithStyle> spans) {
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

  Widget buildChildren(List<String> details, TextStyle style){
    return SelectableText.rich(
        TextSpan(
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
            FlutterLogo(size: 20,),
            SizedBox(width: 4,),
            Text('To Be Continued...', style: TextStyle(fontSize: 24),),
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

class TextWithStyle {
  final String text;
  final TextStyle style;

  TextWithStyle(this.text, this.style);
}
