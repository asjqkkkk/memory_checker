import 'package:flutter/material.dart';

import '../checker_util.dart';
import 'leak_instance_page.dart';

class LeakListPage extends StatefulWidget {
  const LeakListPage({Key key}) : super(key: key);

  @override
  _LeakListPageState createState() => _LeakListPageState();
}

class _LeakListPageState extends State<LeakListPage> {
  MemoryInfo _memoryInfo;

  @override
  void initState() {
    IsoUtil().startCheck().then((value) {
      this._memoryInfo = value.memoryInfo;
      refresh();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leak Instance List'),
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (_memoryInfo == null)
      return Center(
        child: CircularProgressIndicator(),
      );
    final memoryList = _memoryInfo.leakMaps.keys.toList();
    return Container(
      child: ListView.builder(
        itemBuilder: (ctx, index) {
          final curKey = memoryList[index];
          final curLeakInfo = _memoryInfo.leakMaps[curKey];
          return buildLeakItem(curLeakInfo, context);
        },
        itemCount: memoryList.length,
      ),
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Widget buildLeakItem(LeakInfo leakInfo, BuildContext context) {
    final leakCount = leakInfo.instanceObj.totalCount;
    final leakObjName = leakInfo.claObj.name;
    final textStyle =
        Theme.of(context).textTheme.bodyText1.copyWith(fontSize: 18);
    return GestureDetector(
      onTap: () => pushLeakPage(context, leakInfo),
      child: Container(
        margin: EdgeInsets.all(5),
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 10,
              ),
              Container(
                child: Text('Page Leak:'),
                margin: EdgeInsets.only(left: 10, right: 10),
              ),
              Container(
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                              text: TextSpan(
                                  text: 'Leak Object: ',
                                  style: textStyle,
                                  children: [
                                TextSpan(
                                    text: leakObjName,
                                    style: TextStyle(color: Colors.blue))
                              ])),
                          SizedBox(
                            height: 10,
                          ),
                          RichText(
                              text: TextSpan(
                                  text: 'Exist Count: ',
                                  style: textStyle,
                                  children: [
                                TextSpan(
                                    text: '$leakCount',
                                    style: TextStyle(color: Colors.blue))
                              ])),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right)
                  ],
                ),
              ),
              // buildChildLeakList(leakInfo.children, context)
            ],
          ),
        ),
      ),
    );
  }

  Widget buildChildLeakList(List<LeakInfo> leakList, BuildContext context) {
    if (leakList == null || leakList.isEmpty) return SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          child: Text('Field Leak:'),
          margin: EdgeInsets.only(left: 10, right: 10),
        ),
        SingleChildScrollView(
          child: Row(
            children: List.generate(leakList.length, (index) {
              final cur = leakList[index];
              final leakCount = cur.instanceObj.totalCount;
              final leakObjName = cur.claObj.name;
              return GestureDetector(
                onTap: () => pushLeakPage(context, cur),
                child: Container(
                  margin: EdgeInsets.all(8),
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$leakObjName',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(
                        height: 4,
                      ),
                      Text(
                        '$leakCount',
                        style: TextStyle(fontSize: 12),
                      )
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  void pushLeakPage(BuildContext context, LeakInfo leakInfo) {
    Navigator.of(context).push(new MaterialPageRoute(
        builder: (ctx) => LeakInsList(leakInfo: leakInfo)));
  }
}
