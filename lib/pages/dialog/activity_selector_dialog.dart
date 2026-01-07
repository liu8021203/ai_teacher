import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/activity_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:flutter/material.dart';

class ActivitySelectorDialog extends StatefulWidget {
  final String? selectedActivityTitle;
  final Function(String) onActivitySelected;

  const ActivitySelectorDialog({
    super.key,
    required this.selectedActivityTitle,
    required this.onActivitySelected,
  });

  @override
  State<ActivitySelectorDialog> createState() => _ActivitySelectorDialogState();
}

class _ActivitySelectorDialogState extends State<ActivitySelectorDialog>
    with SingleTickerProviderStateMixin {
  List<ActivityListEntity> _allActivities = [];
  List<ActivityListEntity> _categories = []; // 一级分类
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _fetchActivityList();
  }

  @override
  void dispose() {
    if (_categories.isNotEmpty) {
      _tabController.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchActivityList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final int? schoolId = UserManager().getUserInfo()?.schoolId;
      if (schoolId == null) {
        throw Exception('学校ID不存在');
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
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is HttpException ? (e.message ?? '加载失败') : '加载失败';
        });
      }
    }
  }

  List<ActivityListEntity> _getCategoryActivities(int categoryId) {
    return _allActivities.where((item) => item.parentId == categoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '选择活动类型',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E2E2E),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 内容区域
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchActivityList,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF82A6F5),
              ),
              child: const Text('重试', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Text(
          '暂无活动分类',
          style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
        ),
      );
    }

    return Column(
      children: [
        // Tab 栏（一级分类）
        Container(
          color: const Color(0xFFF2F5FF),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const BoxDecoration(color: Colors.transparent),
            dividerColor: Colors.transparent,
            labelColor: const Color(0xFF7EA1FF),
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

        // TabBarView（二级分类列表）
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _categories.map((category) {
              return _buildActivityList(category.id);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityList(int categoryId) {
    final activities = _getCategoryActivities(categoryId);

    if (activities.isEmpty) {
      return const Center(
        child: Text(
          '该分类下暂无活动',
          style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        final isSelected = widget.selectedActivityTitle == activity.categoryTitle;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE5ECFF) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF82A6F5)
                  : const Color(0xFFEEEEEE),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            title: Text(
              activity.categoryTitle,
              style: TextStyle(
                fontSize: 16,
                color: isSelected
                    ? const Color(0xFF82A6F5)
                    : const Color(0xFF2E2E2E),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Color(0xFF82A6F5))
                : null,
            onTap: () {
              widget.onActivitySelected(activity.categoryTitle);
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }
}

