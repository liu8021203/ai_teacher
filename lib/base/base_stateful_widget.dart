import 'package:flutter/material.dart';

class BaseStatefulWidget extends StatefulWidget {
  final AppBar? appBar;
  final FloatingActionButton? floatingActionButton;
  final Widget child;
  final ShowState showState;
  final ReloadDataCallBack reloadDataCallBack;
  final CustomNetworkError? customNetworkError;
  final Color backgroundColor;
  final bool isShowPlayCircle;

  const BaseStatefulWidget({
    super.key,
    this.appBar,
    this.floatingActionButton,
    required this.child,
    required this.showState,
    required this.reloadDataCallBack,
    this.backgroundColor = Colors.white,
    this.isShowPlayCircle = true,
    this.customNetworkError,
  });

  @override
  State<StatefulWidget> createState() => _BaseStatefulWidget();
}

class _BaseStatefulWidget extends State<BaseStatefulWidget> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      color: Colors.transparent,
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: widget.appBar,
        body: _buildBody(),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }

  Widget _buildBody() {
    if (widget.showState is ShowSuccess) {
      return widget.child;
    } else if (widget.showState is ShowNetworkErrorView) {
      return buildNetworkError(
        context,
        widget.customNetworkError,
        reload: () {
          widget.reloadDataCallBack.call();
        },
        errorView: widget.showState as ShowNetworkErrorView,
      );
    } else if (widget.showState is ShowEmptyView) {
      return buildEmptyDataView(context);
    } else {
      return buildLoading();
    }
  }
}

Widget buildLoading({double width = 90, double height = 90}) {
  return Center(
    child: Image.asset(
      'assets/lotties/base_loading.json',
      width: width,
      height: height,
    ),
  );
}

Widget buildEmptyDataView(
  BuildContext context, {
  double width = 150,
  double height = 150,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/lotties/school_book.json',
          width: width,
          height: height,
        ),
        const Text(
          '暂无数据',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget buildNetworkError(
  BuildContext context,
  CustomNetworkError? network, {
  required UIReload reload,
  double width = 150,
  double height = 150,
  double btnWidth = 120,
  double btnHeight = 40,
  double btnTextSize = 14,
  ShowNetworkErrorView errorView = const ShowNetworkErrorView(1, "服务异常"),
}) {
  final customWidget = network?.call(
    errorView.code,
    errorView.message ?? "服务异常",
  );

  if (customWidget != null) {
    return customWidget;
  }
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/lotties/base_network_error.json',
          width: width,
          height: height,
        ),
        SizedBox(height: 20),
        Container(
          width: btnWidth,
          height: btnHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF3CBCFF), Color(0xFF018EFA)],
            ),
          ),
          child: ElevatedButton(
            onPressed: () {
              reload();
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.transparent),
              elevation: MaterialStateProperty.all(0),
            ),
            child: Text(
              "重新加载",
              style: TextStyle(color: Colors.white, fontSize: btnTextSize),
            ),
          ),
        ),
      ],
    ),
  );
}

// enum ShowState { ShowLoading, ShowSuccess, ShowNetworkErrorView, ShowEmptyView }

typedef ReloadDataCallBack = Function();
typedef UIReload = void Function();
typedef CustomNetworkError = Widget? Function(int code, String msg);

abstract class ShowState {
  const ShowState();
}

class ShowLoading extends ShowState {
  const ShowLoading();
}

class ShowSuccess extends ShowState {
  const ShowSuccess();
}

class ShowEmptyView extends ShowState {
  const ShowEmptyView();
}

class ShowNetworkErrorView extends ShowState {
  final int code;
  final String? message;

  const ShowNetworkErrorView(this.code, this.message);
}
