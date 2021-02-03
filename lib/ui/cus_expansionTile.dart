import 'package:flutter/material.dart';

class CusExpansionTile extends StatefulWidget {
  const CusExpansionTile({
    Key key,
    this.leading,
    @required this.title,
    this.subtitle,
    this.backgroundColor,
    this.onExpansionChanged,
    this.dynamicChildren,
    this.trailing,
    this.initiallyExpanded = false,
    this.maintainState = false,
    this.tilePadding,
    this.expandedCrossAxisAlignment,
    this.expandedAlignment,
    this.childrenPadding,
  })  : assert(initiallyExpanded != null),
        assert(maintainState != null),
        assert(
          expandedCrossAxisAlignment != CrossAxisAlignment.baseline,
          'CrossAxisAlignment.baseline is not supported since the expanded children '
          'are aligned in a column, not a row. Try to use another constant.',
        ),
        super(key: key);

  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final ValueChanged<bool> onExpansionChanged;
  final ChildrenBuilder dynamicChildren;
  final Color backgroundColor;
  final Widget trailing;
  final bool initiallyExpanded;
  final bool maintainState;
  final EdgeInsetsGeometry tilePadding;
  final Alignment expandedAlignment;
  final CrossAxisAlignment expandedCrossAxisAlignment;
  final EdgeInsetsGeometry childrenPadding;

  @override
  _CusExpansionTileState createState() => _CusExpansionTileState();
}

class _CusExpansionTileState extends State<CusExpansionTile> {
  bool hasOpened = false;

  @override
  void initState() {
    if (widget.initiallyExpanded) hasOpened = true;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: widget.key,
      leading: widget.leading,
      title: widget.title,
      subtitle: widget.subtitle,
      backgroundColor: widget.backgroundColor,
      onExpansionChanged: (value) {
        widget.onExpansionChanged?.call(value);
        if (value && !hasOpened) {
          hasOpened = true;
          refresh();
        }
      },
      trailing: widget.trailing,
      initiallyExpanded: hasOpened,
      maintainState: widget.maintainState,
      tilePadding: widget.tilePadding,
      expandedCrossAxisAlignment: widget.expandedCrossAxisAlignment,
      expandedAlignment: widget.expandedAlignment,
      childrenPadding: widget.childrenPadding,
      children: getChildren(),
    );
  }

  List<Widget> getChildren() {
    final result = hasOpened ? widget.dynamicChildren?.call() : <Widget>[];
    return result;
  }

  void refresh() {
    if (mounted) setState(() {});
  }
}

typedef ChildrenBuilder = List<Widget> Function();
