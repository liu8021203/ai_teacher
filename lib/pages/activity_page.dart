import 'dart:async';
import 'package:ai_teacher/base/base_stateful_widget.dart';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/activity_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/pages/add_activity_page.dart';
import 'package:ai_teacher/pages/dialog/class_selection_dialog.dart';
import 'package:ai_teacher/util/event_bus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage>
    with TickerProviderStateMixin {
  ShowState _showState = ShowLoading();
  List<ActivityListEntity> _allActivities = [];
  List<ActivityListEntity> _categories = []; // 一级分类
  String _currentClassName = '';
  TabController? _tabController; // 改为可空类型
  StreamSubscription? _classChangedSubscription; // 班级切换事件订阅

  @override
  void initState() {
    super.initState();
    _fetchActivities();
    _loadClassName();

    // 监听班级切换事件
    _classChangedSubscription = eventBus.on<ClassChangedEvent>().listen((
      event,
    ) {
      debugPrint('收到班级切换事件，刷新活动列表');
      _fetchActivities();
      _loadClassName();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _classChangedSubscription?.cancel();
    super.dispose();
  }

  void _loadClassName() {
    // TODO: 可以从本地或接口获取班级名称，这里先写死
    setState(() {
      _currentClassName = 'CASA';
    });
  }

  Future<void> _fetchActivities() async {
    setState(() {
      _showState = ShowLoading();
    });

    try {
      final int? schoolId = UserManager().getUserInfo()?.schoolId;
      if (schoolId == null) {
        throw Exception('学校信息异常');
      }

      List<ActivityListEntity>? list = await DioClient()
          .post<List<ActivityListEntity>>(
            '/activityList',
            data: {'schoolId': schoolId},
            fromJson: (json) {
              if (json is List) {
                return json.map((e) => ActivityListEntity.fromJson(e)).toList();
              }
              return [];
            },
          );

      if (mounted) {
        // 保存旧的 TabController 引用
        final oldController = _tabController;

        setState(() {
          _allActivities = list ?? [];
          // 筛选出一级分类（parentId 为 null）
          _categories = _allActivities
              .where((item) => item.parentId == null)
              .toList();

          // 初始化 TabController
          if (_categories.isNotEmpty) {
            _tabController = TabController(
              length: _categories.length,
              vsync: this,
            );
          }
          _showState = ShowSuccess();
        });

        // 在下一帧释放旧的 TabController，避免在渲染过程中释放
        if (oldController != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            oldController.dispose();
          });
        }
      }
    } catch (e) {
      debugPrint("e : $e");
      if (mounted) {
        if (e is HttpException) {
          setState(() {
            _showState = ShowNetworkErrorView(e.code, e.message ?? '网络异常');
          });
        } else {
          setState(() {
            _showState = ShowNetworkErrorView(-1, '未知错误');
          });
        }
      }
    }
  }

  List<ActivityListEntity> _getCategoryActivities(int categoryId) {
    return _allActivities.where((item) => item.parentId == categoryId).toList();
  }

  Widget _buildCategoryContent(int categoryId) {
    final activities = _getCategoryActivities(categoryId);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: activities.length + 1, // +1 是添加按钮
        itemBuilder: (context, index) {
          // 第一个是添加活动卡片
          if (index == 0) {
            return _buildAddActivityCard(categoryId);
          }

          final activity = activities[index - 1];
          return _buildActivityCard(activity);
        },
      ),
    );
  }

  void _showClassSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ClassSelectionDialog(),
    ).then((_) {
      _loadClassName();
      _fetchActivities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseStatefulWidget(
      showState: _showState,
      reloadDataCallBack: _fetchActivities,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '活动管理',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF82A6F5),
        actions: [
          GestureDetector(
            onTap: _showClassSelectionDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _currentClassName,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部分类Tab栏
          if (_tabController != null)
            Container(
              color: Color(0xFFF2F5FF),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TabBar(
                controller: _tabController!,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                indicatorSize: TabBarIndicatorSize.label,

                indicator: BoxDecoration(color: Colors.transparent),
                dividerColor: Colors.transparent,
                labelColor: Color(0xFF7EA1FF),
                unselectedLabelColor: const Color(0xFF212121),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: _categories.map((category) {
                  return Tab(child: Text(category.categoryTitle));
                }).toList(),
              ),
            ),

          // TabBarView - 可滑动的内容区域
          if (_tabController != null)
            Expanded(
              child: TabBarView(
                controller: _tabController!,
                children: _categories.map((category) {
                  return _buildCategoryContent(category.id);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddActivityCard(int categoryId) {
    return GestureDetector(
      onTap: () async {
        // 跳转到添加活动页面
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddActivityPage(parentId: categoryId),
          ),
        );

        // 如果添加成功（返回了活动名称），刷新活动列表
        if (result != null && result is String) {
          _fetchActivities();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 48, color: Colors.black),
            SizedBox(height: 8),
            Text(
              '添加活动',
              style: TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityListEntity activity) {
    // 解析颜色字符串（如果有）
    Color? cardColor;
    if (activity.color != null && activity.color!.isNotEmpty) {
      try {
        // 假设颜色格式为 #RRGGBB 或 RRGGBB
        String colorStr = activity.color!.replaceAll('#', '');
        cardColor = Color(int.parse('FF$colorStr', radix: 16));
      } catch (e) {
        cardColor = null;
      }
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cardColor ?? const Color(0xFF5B7DBF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片
          if (activity.imageUrl != null && activity.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: activity.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: cardColor ?? const Color(0xFF5B7DBF)),
              errorWidget: (context, url, error) => Container(
                color: cardColor ?? const Color(0xFF5B7DBF),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: 0.3,
                    child: Image.asset(
                      'assets/images/activity_default.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              color: cardColor ?? const Color(0xFF5B7DBF),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: 0.3,
                  child: Image.asset(
                    'assets/images/activity_default.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

          // 渐变遮罩
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 标题文字
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                activity.categoryTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
