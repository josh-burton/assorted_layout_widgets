import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'minimum_raggedness.dart';

// ////////////////////////////////////////////////////////////////////////////

enum WrapType {
  /// Will fit all widgets it can in a line, and then move to the next one.
  fit,

  /// The number of lines will be similar as in [WrapType.fit],
  /// however, it will try to minimize the difference between line widths.
  balanced,
}

// ////////////////////////////////////////////////////////////////////////////

enum WrapFit {
  /// Will keep each widget's original width. This is the default.
  min,

  /// After the calculation, will make widgets fit all the available space.
  /// All widgets in a line will have the same width, even if it makes them
  /// smaller that their original width.
  divided,

  /// After the calculation, will make widgets larger, so that they fit all the
  /// available space. Widgets width will be proportional to their original width.
  proportional,

  /// After the calculation, will make widgets larger, so that they fit all the
  /// available space. Will try to make all widgets the same width,
  /// but won't make any widgets smaller than their original width.
  ///
  /// The procedure is this:
  /// 1) First, divide the available line width by the number of widgets in the
  /// line. That is the preferred width.
  /// 2) Keep the width of all widgets larger than that preferred width.
  /// 3) Calculate the remaining width and divide it equally by the remaining
  /// widgets.
  larger,
}

// ////////////////////////////////////////////////////////////////////////////

enum WrapSuperAlignment {
  left,
  right,
  center,
}

// ////////////////////////////////////////////////////////////////////////////

class WrapSuper extends MultiChildRenderObjectWidget {
  /// `WrapSuper` is a `Wrap` with a better, minimum raggedness algorithm
  /// for line-breaks. Just like a regular `Wrap` widget with
  /// `direction = Axis.horizontal`, `WrapSuper` displays its children in lines.
  /// It will leave `spacing` horizontal space between each child,
  /// and it will leave `lineSpacing` vertical space between each line.
  /// Each line will then be aligned according to the `alignment`.
  ///
  /// `WrapSuper` with `WrapType.fit` is just like `Wrap`.
  ///
  /// However, `WrapSuper` with `WrapType.balanced` (the default)
  /// follows a more balanced layout. It will result in the same number
  /// of lines as `Wrap`, but lines will tend to be more similar in width.
  ///
  /// You can see my original StackOverflow question that prompted this widget here:
  /// https://stackoverflow.com/questions/51679895/in-flutter-how-to-balance-the-children-of-the-wrap-widget
  ///
  /// And you can see the algorithm I am using here (Divide and Conquer):
  /// https://xxyxyz.org/line-breaking/
  ///
  WrapSuper({
    Key? key,
    this.wrapType = WrapType.balanced,
    this.wrapFit = WrapFit.min,
    this.spacing = 0.0,
    this.lineSpacing = 0.0,
    this.alignment = WrapSuperAlignment.left,
    List<Widget> children = const <Widget>[],
  }) : super(key: key, children: children);

  final WrapSuperAlignment alignment;

  /// Defaults to 0.0.
  final double spacing;

  /// Defaults to 0.0.
  final double lineSpacing;

  final WrapType wrapType;

  final WrapFit wrapFit;

  @override
  _RenderWrapSuper createRenderObject(BuildContext context) {
    return _RenderWrapSuper(
      spacing: spacing,
      lineSpacing: lineSpacing,
      alignment: alignment,
      wrapType: wrapType,
      wrapFit: wrapFit,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderWrapSuper renderObject) {
    renderObject
      ..spacing = spacing
      ..lineSpacing = lineSpacing
      ..alignment = alignment
      ..wrapType = wrapType
      ..wrapFit = wrapFit;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _RenderWrapSuper extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox,
            ContainerBoxParentData<RenderBox>>,
        RenderBoxContainerDefaultsMixin<RenderBox,
            ContainerBoxParentData<RenderBox>> {
  //
  _RenderWrapSuper({
    List<RenderBox>? children,
    double spacing = 0.0,
    double lineSpacing = 0.0,
    WrapSuperAlignment alignment = WrapSuperAlignment.left,
    WrapType wrapType = WrapType.balanced,
    WrapFit wrapFit = WrapFit.min,
  })  : _spacing = spacing,
        _lineSpacing = lineSpacing,
        _alignment = alignment,
        _wrapType = wrapType,
        _wrapFit = wrapFit {
    addAll(children);
  }

  /// Defaults to 0.0.
  double get spacing => _spacing;
  double _spacing;

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  /// Defaults to 0.0.
  double get lineSpacing => _lineSpacing;
  double _lineSpacing;

  set lineSpacing(double value) {
    if (_lineSpacing == value) return;
    _lineSpacing = value;
    markNeedsLayout();
  }

  /// Defaults to WrapSuperAlignment.left.
  WrapSuperAlignment get alignment => _alignment;
  WrapSuperAlignment _alignment;

  set alignment(WrapSuperAlignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  WrapType get wrapType => _wrapType;
  WrapType _wrapType;

  set wrapType(WrapType value) {
    if (_wrapType == value) return;
    _wrapType = value;
    markNeedsLayout();
  }

  WrapFit get wrapFit => _wrapFit;
  WrapFit _wrapFit;

  set wrapFit(WrapFit value) {
    if (_wrapFit == value) return;
    _wrapFit = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! WrapParentData)
      child.parentData = WrapParentData();
  }

  double _computeIntrinsicHeightForWidth(double width) {
    int runCount = 0;
    double height = 0.0;
    double runWidth = 0.0;
    double runHeight = 0.0;
    int childCount = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final double childWidth = child.getMaxIntrinsicWidth(double.infinity);
      final double childHeight = child.getMaxIntrinsicHeight(childWidth);
      if (runWidth + childWidth > width) {
        height += runHeight;
        if (runCount > 0) height += lineSpacing;
        runCount += 1;
        runWidth = 0.0;
        runHeight = 0.0;
        childCount = 0;
      }
      runWidth += childWidth;
      runHeight = max(runHeight, childHeight);
      if (childCount > 0) runWidth += spacing;
      childCount += 1;
      child = childAfter(child);
    }
    if (childCount > 0) height += runHeight + lineSpacing;
    return height;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    double width = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      width = max(width, child.getMinIntrinsicWidth(double.infinity));
      child = childAfter(child);
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double width = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      width += child.getMaxIntrinsicWidth(double.infinity);
      child = childAfter(child);
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _computeIntrinsicHeightForWidth(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _computeIntrinsicHeightForWidth(width);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  @override
  void performLayout() {
    if (wrapFit == WrapFit.min)
      performLayoutMin();
    else
      performLayoutElse();
  }

  void performLayoutMin() {
    //
    double availableWidth = constraints.maxWidth;
    var childConstraints = BoxConstraints(maxWidth: availableWidth);

    int count = 0;

    List<ContainerBoxParentData> parentDataList = [];
    List<double> widths = [];
    List<double> heights = [];
    List<_Line> lines = [];

    {
      // First calculate all info.
      RenderBox? child = firstChild;
      while (child != null) {
        child.layout(childConstraints, parentUsesSize: true);

        final double width = child.size.width;
        final double height = child.size.height;
        final childParentData = child.parentData as ContainerBoxParentData;

        count++;
        parentDataList.add(childParentData);
        widths.add(width);
        heights.add(height);

        child = childParentData.nextSibling as RenderBox?;
      }
    }

    // Now calculate which widgets go in which lines.

    // Will try to minimize the difference between line widths.
    if (wrapType == WrapType.balanced) {
      List<List<num>> result =
          MinimumRaggedness.divide(widths, availableWidth, spacing: spacing);
      lines = result
          .map((List<num> indexes) => _Line()..indexes = indexes as List<int>)
          .toList();
    }
    //
    // Will fit all widgets it can in a line, and then move to the next one.
    else if (wrapType == WrapType.fit) {
      double x = 0;
      _Line line = _Line();
      lines.add(line);

      for (int index = 0; index < count; index++) {
        double width = widths[index];

        if (x > 0 && (x + width) > availableWidth) {
          x = 0;
          line = _Line();
          lines.add(line);
        }

        line.indexes.add(index);
        x += width + spacing;
      }
    }
    //
    else
      throw AssertionError(wrapType);

    // ------------------

    double y = 0;
    for (_Line line in lines) {
      double maxY = 0;
      double x = 0;

      for (int index in line.indexes) {
        maxY = max(maxY, heights[index]);
        x += widths[index] + spacing;
      }

      line.width = x - spacing;
      line.top = y;

      y += maxY + lineSpacing;
    }

    for (_Line line in lines) {
      double x;
      if (alignment == WrapSuperAlignment.left)
        x = 0;
      else if (alignment == WrapSuperAlignment.right)
        x = availableWidth - line.width;
      else if (alignment == WrapSuperAlignment.center)
        x = (availableWidth - line.width) / 2;
      else
        x = 0;

      for (int index in line.indexes) {
        var childParentData = parentDataList[index];
        childParentData.offset = Offset(x, line.top);
        x += widths[index] + spacing;
      }
    }

    size = constraints.constrain(Size(availableWidth, y - lineSpacing));
  }

  void performLayoutElse() {
    //
    double availableWidth = constraints.maxWidth;
    int count = 0;

    List<double> widths = [];
    List<double> heights = [];
    List<_Line> lines = [];
    List<RenderBox> children = [];

    {
      // First calculate all info.
      RenderBox? child = firstChild;
      while (child != null) {
        children.add(child);
        final double width = child.computeMaxIntrinsicWidth(double.infinity);
        final double height = child.computeMinIntrinsicHeight(double.infinity);
        widths.add(width);
        heights.add(height);
        child = (child.parentData as ContainerBoxParentData).nextSibling
            as RenderBox?;
      }
    }

    // Now calculate which widgets go in which lines.

    // Will try to minimize the difference between line widths.
    if (wrapType == WrapType.balanced) {
      List<List<num>> result =
          MinimumRaggedness.divide(widths, availableWidth, spacing: spacing);
      lines = result
          .map((List<num> indexes) => _Line()..indexes = indexes as List<int>)
          .toList();
    }
    //
    // Will fit all widgets it can in a line, and then move to the next one.
    else if (wrapType == WrapType.fit) {
      double x = 0;
      _Line line = _Line();
      lines.add(line);

      for (int index = 0; index < count; index++) {
        double width = widths[index];

        if (x > 0 && (x + width) > availableWidth) {
          x = 0;
          line = _Line();
          lines.add(line);
        }

        line.indexes.add(index);
        x += width + spacing;
      }
    }
    //
    else
      throw AssertionError(wrapType);

    // ------------------

    List<ContainerBoxParentData> parentDataList = [];

    if (wrapFit == WrapFit.divided)
      _calculateForWrapFitDivided(
          lines, children, availableWidth, widths, parentDataList);
    //
    else if (wrapFit == WrapFit.proportional)
      _calculateForWrapFitProportional(
          lines, children, availableWidth, widths, parentDataList);
    //
    else if (wrapFit == WrapFit.larger)
      _calculateForWrapFitLarger(
          lines, children, availableWidth, widths, parentDataList);
    //
    else
      throw AssertionError(wrapFit);

    // ------------------

    double y = 0;
    for (_Line line in lines) {
      double maxY = 0;
      double x = 0;

      for (int index in line.indexes) {
        maxY = max(maxY, heights[index]);
        x += widths[index] + spacing;
      }

      line.width = x - spacing;
      line.top = y;

      y += maxY + lineSpacing;
    }

    for (_Line line in lines) {
      double x;
      if (alignment == WrapSuperAlignment.left)
        x = 0;
      else if (alignment == WrapSuperAlignment.right)
        x = availableWidth - line.width;
      else if (alignment == WrapSuperAlignment.center)
        x = (availableWidth - line.width) / 2;
      else
        x = 0;

      for (int index in line.indexes) {
        var childParentData = parentDataList[index];
        childParentData.offset = Offset(x, line.top);
        x += widths[index] + spacing;
      }
    }

    size = constraints.constrain(Size(availableWidth, y - lineSpacing));
  }

  /// After the calculation, will make widgets fit all the available space.
  /// All widgets in a line will have the same width, even if it makes them
  /// smaller that their original width.
  void _calculateForWrapFitDivided(
    List<_Line> lines,
    List<RenderBox> children,
    double availableWidth,
    List<double> widths,
    List<ContainerBoxParentData<RenderObject>> parentDataList,
  ) {
    for (_Line line in lines) {
      var numberOfChildrenInLine = line.indexes.length;
      for (int index in line.indexes) {
        var child = children[index];

        var availableWidthMinusSpacing =
            (availableWidth - (spacing * (numberOfChildrenInLine - 1)));

        var width = availableWidthMinusSpacing / numberOfChildrenInLine;

        BoxConstraints childConstraints =
            BoxConstraints(minWidth: width, maxWidth: width);

        child.layout(childConstraints, parentUsesSize: true);

        widths[index] = width;

        final childParentData = child.parentData as ContainerBoxParentData;
        parentDataList.add(childParentData);
      }
    }
  }

  /// After the calculation, will make widgets larger, so that they fit all the
  /// available space. Widgets width will be proportional to their original width.
  void _calculateForWrapFitProportional(
    List<_Line> lines,
    List<RenderBox> children,
    double availableWidth,
    List<double> widths,
    List<ContainerBoxParentData<RenderObject>> parentDataList,
  ) {
    for (_Line line in lines) {
      //
      var numberOfChildrenInLine = line.indexes.length;

      double sumOfWidgetsInLine = 0;

      for (var index in line.indexes) {
        sumOfWidgetsInLine += widths[index];
      }

      var availableWidthMinusSpacing =
          (availableWidth - (spacing * (numberOfChildrenInLine - 1)));

      for (int index in line.indexes) {
        var child = children[index];

        var width =
            availableWidthMinusSpacing * (widths[index] / sumOfWidgetsInLine);

        BoxConstraints childConstraints =
            BoxConstraints(minWidth: width, maxWidth: width);

        child.layout(childConstraints, parentUsesSize: true);

        widths[index] = width;

        final childParentData = child.parentData as ContainerBoxParentData;
        parentDataList.add(childParentData);
      }
    }
  }

  /// After the calculation, will make widgets larger, so that they fit all the
  /// available space. Will try to make all widgets the same width,
  /// but won't make any widgets smaller than their original width.
  ///
  /// The procedure is this:
  /// 1) First, divide the available line width by the number of widgets in the
  /// line. That is the preferred width.
  /// 2) Keep the width of all widgets larger than that preferred width.
  /// 3) Calculate the remaining width and divide it equally by the remaining
  /// widgets.
  void _calculateForWrapFitLarger(
    List<_Line> lines,
    List<RenderBox> children,
    double availableWidth,
    List<double> widths,
    List<ContainerBoxParentData<RenderObject>> parentDataList,
  ) {
    for (_Line line in lines) {
      var numberOfChildrenInLine = line.indexes.length;

      var availableWidthMinusSpacing =
          (availableWidth - (spacing * (numberOfChildrenInLine - 1)));

      var remainingWidth = availableWidthMinusSpacing;

      // 1) First, divide the available line width by the number
      // of widgets in the line. That is the preferred width.
      var preferredWidth = availableWidthMinusSpacing / line.indexes.length;

      // 3) Calculate the remaining width.
      int numberOfLargerWidgets = 0;
      for (int index in line.indexes) {
        var childWidth = widths[index];

        if (childWidth >= preferredWidth) {
          numberOfLargerWidgets++;
          remainingWidth -= childWidth;
        }
      }

      // 3) Divide the remaining width by the remaining widgets.
      var preferredWidthForRemainingWidgets =
          remainingWidth / (line.indexes.length - numberOfLargerWidgets);

      for (int index in line.indexes) {
        var child = children[index];
        var childWidth = widths[index];

        BoxConstraints childConstraints;

        // 2) Keep the width of all widgets larger than that preferred width.
        if (childWidth >= preferredWidth) {
          if (childWidth > availableWidthMinusSpacing) {
            widths[index] = availableWidthMinusSpacing;
            childConstraints = BoxConstraints(
                minWidth: availableWidthMinusSpacing,
                maxWidth: availableWidthMinusSpacing);
          } else
            childConstraints =
                BoxConstraints(minWidth: childWidth, maxWidth: childWidth);
        }
        // 3) Divide the remaining width by the remaining widgets.
        else {
          childConstraints = BoxConstraints(
              minWidth: preferredWidthForRemainingWidgets,
              maxWidth: preferredWidthForRemainingWidgets);
          widths[index] = preferredWidthForRemainingWidgets;
        }

        child.layout(childConstraints, parentUsesSize: true);

        final childParentData = child.parentData as ContainerBoxParentData;
        parentDataList.add(childParentData);
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _Line {
  List<int> indexes = [];
  double width = 0;
  double top = 0;
}

// ////////////////////////////////////////////////////////////////////////////
