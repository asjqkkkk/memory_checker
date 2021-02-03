import 'package:flutter/material.dart';
import 'package:memory_checker/ui/common_ui.dart';
import 'package:vm_service/vm_service.dart' as vs;

import '../memory_checker.dart';
import 'leak_info_page.dart';

class LeakInsList extends StatefulWidget {
  final LeakInfo leakInfo;

  const LeakInsList({Key key, this.leakInfo}) : super(key: key);

  @override
  _LeakInsListState createState() => _LeakInsListState();
}

class _LeakInsListState extends State<LeakInsList> {
  List<vs.ObjRef> _instances;

  @override
  void initState() {
    final targetId = widget.leakInfo.claObj.id;
    getInstances(ObjectInfo(targetId, limit: 100)).then((value) {
      _instances = value.instances;
      refresh();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.leakInfo.claObj.name;
    return Scaffold(
      appBar: AppBar(
        title: Text('$name-List'),
      ),
      body: buildBody(name, context),
    );
  }

  Widget buildBody(String name, BuildContext context) {
    if (_instances == null) return loadingWidget();
    if (_instances.isEmpty) return noMoreWidget();
    return ListView.builder(
      itemBuilder: (ctx, index) {
        final obj = _instances[index];
        return ListTile(
          title: Text(name),
          trailing: Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(new MaterialPageRoute(
                builder: (ctx) => LeakInfoPage(
                      leakInfo: widget.leakInfo,
                      objRef: obj,
                    )));
          },
        );
      },
      itemCount: _instances.length,
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }
}
