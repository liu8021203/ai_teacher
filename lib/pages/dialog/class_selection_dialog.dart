import 'package:ai_teacher/base/base_stateful_widget.dart';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/class_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/util/event_bus.dart';
import 'package:ai_teacher/util/sp_util.dart';
import 'package:flutter/material.dart';

class ClassSelectionDialog extends StatefulWidget {
  const ClassSelectionDialog({super.key});

  @override
  State<ClassSelectionDialog> createState() => _ClassSelectionDialogState();
}

class _ClassSelectionDialogState extends State<ClassSelectionDialog> {
  // 0: loading, 1: success, 2: fail
  ShowState _showState = ShowLoading();
  List<ClassListEntity>? _classList = null;

  @override
  void initState() {
    super.initState();
    _fetchClassList();
  }

  Future<void> _fetchClassList() async {
    setState(() {
      _showState = ShowLoading();
    });

    try {
      // 获取用户 schoolId
      final int? schoolId = UserManager().getUserInfo()?.schoolId;
      // 注意：如果 UserManager 中没有保存 schoolId，需要确保在登录时保存了
      // 临时兜底：如果为 null，模拟一个或者抛出异常
      if (schoolId == null) {
        return;
      }

      // 请求接口
      // 后端返回的 data 是一个数组，所以这里解析为 List<ClassEntity>
      // 假设后端返回结构: {code: 0, message: "ok", data: [{classId: "1", className: "xx"}, ...]}
      // DioClient 会自动剥离 BaseResult 的外壳，返回 data
      List<ClassListEntity>? list = await DioClient()
          .post<List<ClassListEntity>>(
            '/classList',
            data: {'schoolId': schoolId},
            fromJson: (json) {
              // json 此时已经是 data 字段的内容了
              if (json is List) {
                return json.map((e) => ClassListEntity.fromJson(e)).toList();
              }
              return [];
            },
          );

      if (mounted) {
        setState(() {
          _classList = list;
          _showState = ShowSuccess();
        });
      }
    } catch (e) {
      HttpException? exception = e as HttpException?;
      if (exception != null) {
        if (mounted) {
          setState(() {
            _showState = ShowNetworkErrorView(
              exception.code,
              exception.message,
            );
          });
        }
      }
    }
  }

  Future<void> _onClassSelected(ClassListEntity item) async {
    SPUtil.setString("classId", item.id.toString());
    // 发送班级切换事件，通知其他页面刷新数据
    eventBus.fire(ClassChangedEvent());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 禁止返回键关闭
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择班级',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 30),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_showState is ShowLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: CircularProgressIndicator(),
      );
    } else if (_showState is ShowNetworkErrorView) {
      return Column(
        children: [
          Text(
            '加载失败',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _fetchClassList, child: const Text('重试')),
        ],
      );
    } else {
      if (_classList == null) {
        return const Text('暂无班级信息');
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _classList!.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final item = _classList![index];
            return GestureDetector(
              onTap: () => _onClassSelected(item),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5ECFF),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  item.className,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  }
}
