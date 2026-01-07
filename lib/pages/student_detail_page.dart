import 'dart:async';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/activity_list_entity.dart';
import 'package:ai_teacher/http/model/daily_analyze_result_entity.dart';
import 'package:ai_teacher/http/model/student_data_confirm_list_entity.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/pages/dialog/edit_student_data_dialog.dart';
import 'package:ai_teacher/pages/dialog/student_info_dialog.dart';
import 'package:ai_teacher/util/event_bus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';

class StudentDetailPage extends StatefulWidget {
  final int studentId;

  const StudentDetailPage({super.key, required this.studentId});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  List<StudentDataConfirmListEntity> _dataList = [];
  List<ActivityListEntity> _activityList = [];
  bool _isLoading = true;
  String? _errorMessage;
  StudentListEntity? _currentStudent; // 当前学生信息
  StreamSubscription? _studentDataChangedSubscription; // 事件订阅
  late TabController _tabController; // Tab控制器

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 观察和日报两个Tab
    _fetchStudentInfo(); // 获取最新学生信息
    _fetchActivityList();
    _fetchStudentData();

    // 监听学生数据变更事件
    _studentDataChangedSubscription = eventBus
        .on<StudentDataChangedEvent>()
        .listen((event) {
          _fetchStudentInfo(); // 刷新学生信息
        });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentDataChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchStudentInfo() async {
    try {
      StudentListEntity? student = await DioClient().post<StudentListEntity>(
        '/getStudentInfo',
        data: {'studentId': widget.studentId},
        fromJson: (json) => StudentListEntity.fromJson(json),
      );

      if (mounted && student != null) {
        setState(() {
          _currentStudent = student;
        });
      }
    } catch (e) {
      debugPrint('获取学生信息失败: $e');
    }
  }

  Future<void> _fetchActivityList() async {
    try {
      final int? schoolId = UserManager().getUserInfo()?.schoolId;
      if (schoolId == null) {
        return;
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
          _activityList = list ?? [];
        });
      }
    } catch (e) {
      debugPrint('获取活动列表失败: $e');
    }
  }

  Future<void> _fetchStudentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      List<StudentDataConfirmListEntity>? list = await DioClient()
          .post<List<StudentDataConfirmListEntity>>(
            '/getStudentData',
            data: {'studentId': widget.studentId, 'date': dateStr},
            fromJson: (json) {
              if (json is List) {
                return json
                    .map((e) => StudentDataConfirmListEntity.fromJson(e))
                    .toList();
              }
              return null;
            },
          );

      if (mounted) {
        setState(() {
          _dataList = list ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is HttpException ? e.message : '加载失败';
        });
      }
    }
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF82A6F5)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchStudentData();
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatTime(String createDate) {
    try {
      final date = DateTime.parse(createDate);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '--:--';
    }
  }

  ActivityListEntity? _findActivityByName(String? activityName) {
    if (activityName == null || activityName.isEmpty) {
      return null;
    }
    try {
      return _activityList.firstWhere(
        (activity) => activity.categoryTitle == activityName,
      );
    } catch (e) {
      return null;
    }
  }

  Color _getColorByParentId(int? parentId) {
    if (parentId == null) {
      return const Color(0xFFFFC88D); // 默认颜色
    }

    switch (parentId) {
      case 1:
        return const Color(0xFFBED0FF);
      case 2:
        return const Color(0xFFE5FDFF);
      case 3:
        return const Color(0xFFFFFDCE);
      case 4:
        return const Color(0xFFFFE5F3);
      case 5:
        return const Color(0xFFEFFFE5);
      default:
        return const Color(0xFFFFC88D);
    }
  }

  Color _getActivityTitleColorByParentId(int? parentId) {
    if (parentId == null) {
      return const Color(0xFFB1600A); // 默认颜色
    }

    switch (parentId) {
      case 1:
        return const Color(0xFF44588D);
      case 2:
        return const Color(0xFF549CA2);
      case 3:
        return const Color(0xFF817901);
      case 4:
        return const Color(0xFF6F004F);
      case 5:
        return const Color(0xFF407939);
      default:
        return const Color(0xFFB1600A);
    }
  }

  void _showEditDialog(StudentDataConfirmListEntity data, int? parentId) {
    showDialog(
      context: context,
      builder: (context) => EditStudentDataDialog(
        data: data,
        parentId: parentId,
        onSaveSuccess: () {
          _fetchStudentData();
        },
      ),
    );
  }

  void _showMoveDialog(StudentDataConfirmListEntity data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _MoveStudentSheet(
          data: data,
          onMoveSuccess: () {
            _fetchStudentData();
          },
        );
      },
    );
  }

  void _showDeleteDialog(StudentDataConfirmListEntity data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条数据吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteStudentData(data);
            },
            child: const Text('确定', style: TextStyle(color: Color(0xFF8D0D0D))),
          ),
        ],
      ),
    );
  }

  void _showStudentInfoDialog() {
    if(_currentStudent == null){
      return;
    }
    showDialog(
      context: context,
      builder: (context) => StudentInfoDialog(
        student: _currentStudent!,
        onDelete: () {
          // 删除成功后返回上一页
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _deleteStudentData(StudentDataConfirmListEntity data) async {
    try {
      context.loaderOverlay.show();

      await DioClient().post(
        '/deleteStudentData',
        data: {'id': data.id},
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        Fluttertoast.showToast(msg: '删除成功');
        _fetchStudentData();
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '删除失败') : '删除失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentStudent?.studentName}的主页',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF82A6F5),
        elevation: 0,
        actions: [
          CustomPopup(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupItem(Icons.person, '个人信息', () {
                  Navigator.of(context).pop(); // 关闭popup
                  // 延迟显示dialog，确保popup完全关闭
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      _showStudentInfoDialog();
                    }
                  });
                }),
                _buildPopupItem(Icons.article, '周报', () {}),
                _buildPopupItem(Icons.calendar_month, '月报', () {}),
              ],
            ),
            backgroundColor: Colors.white,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Icon(Icons.menu, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部Tab栏（系统组件）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF212121),
              indicator: BoxDecoration(
                color: const Color(0xFF7EA1FF),
                borderRadius: BorderRadius.circular(20),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: '观察'),
                Tab(text: '日报'),
              ],
            ),
          ),

          // TabBarView内容区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 观察页面
                _buildObservationTab(),
                // 日报页面
                _DailyReportTab(
                  studentId: _currentStudent?.id ?? 0,
                  selectedDate: _selectedDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 观察页面Tab内容
  Widget _buildObservationTab() {
    return Column(
      children: [
        // 日期选择栏
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Text(
                _isToday(_selectedDate)
                    ? '今天'
                    : DateFormat('yyyy-MM-dd').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('EEEE', 'zh_CN').format(_selectedDate),
                style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),

        // 内容区域
        Expanded(
          child: Container(
            color: Colors.white,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchStudentData,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : _dataList.isEmpty
                ? const Center(
                    child: Text(
                      '暂无数据',
                      style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _dataList.length,
                    itemBuilder: (context, index) {
                      return _buildDataCard(_dataList[index], index);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataCard(StudentDataConfirmListEntity data, int index) {
    // 根据活动名称找到对应的活动数据，然后根据 parentId 决定背景颜色
    final activity = _findActivityByName(data.activity);
    final backgroundColor = _getColorByParentId(activity?.parentId);
    final activityTitleColor = _getActivityTitleColorByParentId(
      activity?.parentId,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF424242), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 内容区域
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 活动标题
                Row(
                  children: [
                    Text(
                      data.activity ?? '未知活动',
                      style: TextStyle(fontSize: 12, color: activityTitleColor),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(data.createDate),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 描述内容
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFD7D6E8), width: 1),
                  ),
                  child: Text(
                    data.description ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E2E2E),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 底部操作按钮
                Row(
                  children: [
                    const Spacer(),
                    _buildActionButton(
                      'assets/images/student_details_edit.png',
                      Color(0xFF44588D),
                      '编辑',
                      () => _showEditDialog(data, activity?.parentId),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      'assets/images/student_details_delete.png',
                      Color(0xFF8D0D0D),
                      '删除',
                      () => _showDeleteDialog(data),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      'assets/images/student_details_move.png',
                      Color(0xFF44588D),
                      '移动',
                      () => _showMoveDialog(data),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Image.asset(icon, width: 20, height: 20),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildPopupItem(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          // mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF333333)),
            const SizedBox(width: 8),
            Expanded(
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveStudentSheet extends StatefulWidget {
  final StudentDataConfirmListEntity data;
  final VoidCallback? onMoveSuccess;

  const _MoveStudentSheet({required this.data, this.onMoveSuccess});

  @override
  State<_MoveStudentSheet> createState() => _MoveStudentSheetState();
}

class _MoveStudentSheetState extends State<_MoveStudentSheet> {
  List<StudentListEntity> _studentList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudentList();
  }

  Future<void> _fetchStudentList() async {
    debugPrint("_fetchStudentList : ${widget.data.studentId}");
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.data.studentId == null) {
        throw Exception('学生ID不存在');
      }

      List<StudentListEntity>? list = await DioClient()
          .post<List<StudentListEntity>>(
            '/getCanMoveStudentList',
            data: {'studentId': widget.data.studentId},
            fromJson: (json) {
              if (json is List) {
                return json.map((e) => StudentListEntity.fromJson(e)).toList();
              }
              return [];
            },
          );

      if (mounted) {
        setState(() {
          _studentList = list ?? [];
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

  Future<void> _moveToStudent(StudentListEntity student) async {
    try {
      context.loaderOverlay.show();

      await DioClient().post(
        '/moveStudentData',
        data: {
          'id': widget.data.id,
          'studentId': student.id,
          'studentName': student.studentName,
        },
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        Fluttertoast.showToast(msg: '移动成功');
        Navigator.of(context).pop();
        widget.onMoveSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '移动失败') : '移动失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              '选择要移动到的学生',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E2E2E),
              ),
            ),
          ),
          const Divider(),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchStudentList,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF82A6F5),
                ),
                child: const Text('重试', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_studentList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '暂无可移动的学生',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _studentList.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final student = _studentList[index];
        return ListTile(
          leading: ClipOval(
            child:
                student.studentAvatar != null &&
                    student.studentAvatar!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: student.studentAvatar!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(Icons.person, color: Color(0xFFCCCCCC)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(Icons.person, color: Color(0xFFCCCCCC)),
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: const Color(0xFFF5F5F5),
                    child: const Icon(Icons.person, color: Color(0xFFCCCCCC)),
                  ),
          ),
          title: Text(
            student.studentName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2E2E2E),
            ),
          ),
          subtitle:
              student.studentNickName != null &&
                  student.studentNickName!.isNotEmpty
              ? Text(
                  student.studentNickName!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF999999),
                  ),
                )
              : null,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _moveToStudent(student),
        );
      },
    );
  }
}

// 日报Tab页面
class _DailyReportTab extends StatefulWidget {
  final int studentId;
  final DateTime selectedDate;

  const _DailyReportTab({required this.studentId, required this.selectedDate});

  @override
  State<_DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<_DailyReportTab>
    with TickerProviderStateMixin {
  int _analyzeStatus = 0; // 0: 加载中, 1: 没有数据, 2: AI分析中, 3: 可以分析, 4: 已分析
  bool _isLoading = true;
  DailyAnalyzeResultEntity? _analyzeData;
  late TabController _activityTabController;
  int _selectedActivityIndex = 0;
  bool _isEditing = false; // 是否处于编辑模式
  Map<String, TextEditingController> _editControllers = {}; // 编辑控制器
  Timer? _statusCheckTimer; // 状态检查定时器

  @override
  void initState() {
    super.initState();
    _activityTabController = TabController(length: 0, vsync: this);
    _fetchDailyAnalyzeStatus();
  }

  @override
  void didUpdateWidget(_DailyReportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当日期变化时重新获取状态
    if (oldWidget.selectedDate != widget.selectedDate) {
      _fetchDailyAnalyzeStatus();
    }
  }

  @override
  void dispose() {
    _activityTabController.dispose();
    _statusCheckTimer?.cancel(); // 取消定时器
    // 释放所有编辑控制器
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchDailyAnalyzeStatus() async {
    setState(() {
      _isLoading = true;
      _analyzeData = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      debugPrint('===== 开始获取日报状态 =====');
      debugPrint('studentId: ${widget.studentId}, date: $dateStr');

      final result = await DioClient().post<int>(
        '/dailyAnalyzeStatus',
        data: {'studentId': widget.studentId, 'date': dateStr},
        fromJson: (json) => json as int,
      );

      debugPrint('日报状态返回: $result');

      if (mounted) {
        setState(() {
          _analyzeStatus = result ?? 1;
          _isLoading = false;
        });

        debugPrint('当前状态: $_analyzeStatus');

        // 如果状态为3或4，获取分析数据
        if (_analyzeStatus == 3 || _analyzeStatus == 4) {
          debugPrint('状态为 $_analyzeStatus，开始获取日报数据');
          _fetchDailyAnalyzeData();
        } else {
          debugPrint('状态为 $_analyzeStatus，不获取日报数据');
        }
      }
    } catch (e) {
      debugPrint('获取日报状态失败: $e');
      if (mounted) {
        setState(() {
          _analyzeStatus = 1;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDailyAnalyzeData() async {
    try {
      debugPrint('===== 开始获取日报数据 =====');
      debugPrint('调用 /dailyAnalyzeData, studentId: ${widget.studentId}');

      DailyAnalyzeResultEntity? data = await DioClient()
          .post<DailyAnalyzeResultEntity>(
            '/dailyAnalyzeData',
            data: {'studentId': widget.studentId},
            fromJson: (json) {
              debugPrint('日报数据原始JSON: $json');
              return json == null
                  ? null
                  : DailyAnalyzeResultEntity.fromJson(json);
            },
          );

      debugPrint('日报数据获取成功: ${data != null}');
      if (data != null) {
        debugPrint('summary: ${data.summary}');
        debugPrint('analyzeData 数量: ${data.analyzeData?.length ?? 0}');
        if (data.analyzeData != null && data.analyzeData!.isNotEmpty) {
          debugPrint('第一个活动: ${data.analyzeData![0].activity_name}');
        }
      }

      if (mounted && data != null) {
        setState(() {
          _analyzeData = data;
          // 更新TabController
          final activityCount = data.analyzeData?.length ?? 0;
          debugPrint('更新 TabController, 活动数量: $activityCount');
          _activityTabController.dispose();
          _activityTabController = TabController(
            length: activityCount,
            vsync: this,
          );
          _selectedActivityIndex = 0;
        });
        debugPrint('日报数据设置完成，_analyzeData != null: ${_analyzeData != null}');
      } else {
        debugPrint('数据为空或组件已销毁: mounted=$mounted, data=$data');
      }
    } catch (e, stackTrace) {
      debugPrint('获取日报数据失败: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _startAnalyze() async {
    try {
      context.loaderOverlay.show();

      await DioClient().post(
        '/dailyAnalyze',
        data: {'studentId': widget.studentId},
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        Fluttertoast.showToast(msg: '开始分析，请稍后查看');
        // 重新获取状态
        setState(() {
          _analyzeStatus = 2;
        });

        // 启动定时器，10秒后检查状态
        _startStatusCheckTimer();

        // 发送事件通知 RecordPage 刷新未读数据
        eventBus.fire(DailyAnalyzeStartedEvent());
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '分析失败') : '分析失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  // 启动状态检查定时器
  void _startStatusCheckTimer() {
    // 取消之前的定时器（如果存在）
    _statusCheckTimer?.cancel();

    // 启动新的定时器，10秒后检查状态
    _statusCheckTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        debugPrint('定时器触发：开始检查日报状态');
        _fetchDailyAnalyzeStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('===== DailyReportTab build =====');
    debugPrint('_isLoading: $_isLoading');
    debugPrint('_analyzeStatus: $_analyzeStatus');
    debugPrint('_analyzeData != null: ${_analyzeData != null}');

    if (_isLoading) {
      debugPrint('显示加载中...');
      return const Center(child: CircularProgressIndicator());
    }

    // 根据状态显示不同UI
    if (_analyzeStatus == 1) {
      debugPrint('显示：暂无数据');
      // 没有数据
      return const Center(
        child: Text(
          '暂无数据',
          style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
        ),
      );
    } else if (_analyzeStatus == 2) {
      debugPrint('显示：AI分析中');
      // AI分析中
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'AI分析中，请稍后...',
              style: TextStyle(fontSize: 16, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    } else if (_analyzeStatus == 3) {
      debugPrint('显示：可以进行分析界面');
      // 可以进行分析（无数据）
      if (_analyzeData != null) {
        return _buildDataView();
      } else {
        return _buildAnalyzeView();
      }
    } else if (_analyzeStatus == 4) {
      debugPrint('显示：数据展示界面, _analyzeData: ${_analyzeData != null}');
      // 已有分析数据
      return _buildDataView();
    }

    debugPrint('显示：空 SizedBox (未知状态: $_analyzeStatus)');
    return const SizedBox();
  }

  Widget _buildAnalyzeView() {
    // 格式化日期
    String weekday = '';
    switch (widget.selectedDate.weekday) {
      case 1:
        weekday = '周一';
        break;
      case 2:
        weekday = '周二';
        break;
      case 3:
        weekday = '周三';
        break;
      case 4:
        weekday = '周四';
        break;
      case 5:
        weekday = '周五';
        break;
      case 6:
        weekday = '周六';
        break;
      case 7:
        weekday = '周日';
        break;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 顶部卡片
          Card(
            color: Color(0xFFF6F6F8),
            elevation: 5,
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // 标题和日期
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Color(0xFFA5BEFF),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(16),
                        topLeft: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '今日概要',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$weekday，$dateStr',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                  // 提示文字
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: const Text(
                      '确认观察内容无误后，点击按钮立即分析',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // 提示文字
          const Text(
            '每日下午7点自动分析',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),

          const SizedBox(height: 20),

          // 立即分析按钮
          ElevatedButton(
            onPressed: _startAnalyze,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBED0FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(60),
              ),
              elevation: 0,
              side: BorderSide(color: Color(0xFF7EA1FF), width: 2),
            ),
            child: const Text(
              '立即分析',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 展示分析数据
  Widget _buildDataView() {
    if (_analyzeData == null) {
      debugPrint('_analyzeData 为空，显示加载中');
      // return const Center(child: CircularProgressIndicator());
      return _buildAnalyzeView();
    }

    // 格式化日期
    String weekday = '';
    switch (widget.selectedDate.weekday) {
      case 1:
        weekday = '周一';
        break;
      case 2:
        weekday = '周二';
        break;
      case 3:
        weekday = '周三';
        break;
      case 4:
        weekday = '周四';
        break;
      case 5:
        weekday = '周五';
        break;
      case 6:
        weekday = '周六';
        break;
      case 7:
        weekday = '周日';
        break;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 顶部概要卡片
            Card(
              color: Color(0xFFF6F6F8),
              elevation: 5,
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 标题和日期
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFA5BEFF),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                          topLeft: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '今日概要',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '$weekday，$dateStr',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 概要内容
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        _analyzeData!.summary ?? '暂无概要',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2E2E2E),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 活动细节标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: const Text(
                '活动细节',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 活动Tab栏（水平滚动）
            if (_analyzeData!.analyzeData != null &&
                _analyzeData!.analyzeData!.isNotEmpty)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _analyzeData!.analyzeData!.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedActivityIndex == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedActivityIndex = index;
                          _activityTabController.animateTo(index);
                          // 如果正在编辑，需要重新初始化编辑控制器
                          if (_isEditing) {
                            _enterEditMode();
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE5ECFF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _analyzeData!.analyzeData![index].activity_name ??
                                '未知活动',
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? const Color(0xFF2E2E2E)
                                  : const Color(0xFF666666),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // 活动详细内容
            if (_analyzeData!.analyzeData != null &&
                _analyzeData!.analyzeData!.isNotEmpty)
              _buildActivityDetails(
                _analyzeData!.analyzeData![_selectedActivityIndex],
              ),

            const SizedBox(height: 100), // 底部留空，避免被按钮遮挡
          ],
        ),
      ),
      floatingActionButton: _analyzeStatus == 4 || _analyzeStatus == 3
          ? _buildFloatingButtons()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // 构建悬浮按钮
  Widget _buildFloatingButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_analyzeStatus == 4) ...[
            // 编辑/保存按钮
            Expanded(
              child: ElevatedButton(
                onPressed: _isEditing ? _saveData : _enterEditMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5ECFF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(60),
                  ),
                  elevation: 4,
                  side: BorderSide(color: Color(0xFF7EA1FF), width: 2),
                ),
                child: Text(
                  _isEditing ? '保存' : '编辑',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 继续分析按钮
            Expanded(
              child: ElevatedButton(
                onPressed: _startAnalyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBED0FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(60),
                  ),
                  elevation: 4,
                  side: BorderSide(color: Color(0xFF7EA1FF), width: 2),
                ),
                child: const Text(
                  '继续分析',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ] else ...[
            // 立即分析按钮（状态3）
            ElevatedButton(
              onPressed: _isEditing ? _saveData : _enterEditMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBED0FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(60),
                ),
                elevation: 4,
                side: BorderSide(color: Color(0xFF7EA1FF), width: 2),
              ),
              child: Text(
                _isEditing ? '保存' : '编辑',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 进入编辑模式
  void _enterEditMode() {
    setState(() {
      _isEditing = true;
      // 初始化编辑控制器
      _editControllers.clear();
      if (_analyzeData?.analyzeData != null &&
          _analyzeData!.analyzeData!.isNotEmpty) {
        final currentActivity =
            _analyzeData!.analyzeData![_selectedActivityIndex];

        // 为每个字段创建控制器
        final allFields = [
          {'key': 'social', 'value': currentActivity.social},
          {'key': 'interaction', 'value': currentActivity.interaction},
          {'key': 'action', 'value': currentActivity.action},
          {'key': 'error_control', 'value': currentActivity.error_control},
          {'key': 'finish', 'value': currentActivity.finish},
          {'key': 'give_up', 'value': currentActivity.give_up},
          {'key': 'layout', 'value': currentActivity.layout},
          {'key': 'operation', 'value': currentActivity.operation},
          {'key': 'paralanguage', 'value': currentActivity.paralanguage},
          {'key': 'persist', 'value': currentActivity.persist},
          {'key': 'repeat', 'value': currentActivity.repeat},
          {'key': 'sequence', 'value': currentActivity.sequence},
          {'key': 'work_dur', 'value': currentActivity.work_dur},
          {'key': 'work_selection', 'value': currentActivity.work_selection},
          {'key': 'work_style', 'value': currentActivity.work_style},
        ];

        for (var field in allFields) {
          if (field['value'] != null && field['value'].toString().isNotEmpty) {
            _editControllers[field['key'] as String] = TextEditingController(
              text: field['value'].toString(),
            );
          }
        }
      }
    });
  }

  // 保存数据
  Future<void> _saveData() async {
    try {
      context.loaderOverlay.show();

      if (_analyzeData?.analyzeData == null ||
          _analyzeData!.analyzeData!.isEmpty) {
        throw Exception('数据为空');
      }

      final currentActivity =
          _analyzeData!.analyzeData![_selectedActivityIndex];

      // 构建保存的数据
      Map<String, dynamic> saveData = {
        'studentId': widget.studentId,
        'summary_id': currentActivity.summary_id,
      };

      // 添加所有编辑的字段
      _editControllers.forEach((key, controller) {
        saveData[key] = controller.text;
      });

      // 调用API保存数据
      await DioClient().post(
        '/editDailyAnalyze',
        data: saveData,
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        setState(() {
          _isEditing = false;
          // 清空编辑控制器
          for (var controller in _editControllers.values) {
            controller.dispose();
          }
          _editControllers.clear();
        });
        Fluttertoast.showToast(msg: '保存成功');
        // 重新获取数据
        _fetchDailyAnalyzeData();
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '保存失败') : '保存失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  // 构建活动详细内容
  Widget _buildActivityDetails(dynamic activityData) {
    List<Widget> detailWidgets = [];

    // 添加所有字段
    final allFields = [
      {'key': 'social', 'label': '社交性', 'value': activityData.social},
      {'key': 'interaction', 'label': '独立性', 'value': activityData.interaction},
      {'key': 'action', 'label': '动作', 'value': activityData.action},
      {
        'key': 'error_control',
        'label': '错误控制',
        'value': activityData.error_control,
      },
      {'key': 'finish', 'label': '完成', 'value': activityData.finish},
      {'key': 'give_up', 'label': '放弃', 'value': activityData.give_up},
      {'key': 'layout', 'label': '布局', 'value': activityData.layout},
      {'key': 'operation', 'label': '操作', 'value': activityData.operation},
      {
        'key': 'paralanguage',
        'label': '副语言',
        'value': activityData.paralanguage,
      },
      {'key': 'persist', 'label': '坚持', 'value': activityData.persist},
      {'key': 'repeat', 'label': '重复', 'value': activityData.repeat},
      {'key': 'sequence', 'label': '顺序', 'value': activityData.sequence},
      {'key': 'work_dur', 'label': '工作时长', 'value': activityData.work_dur},
      {
        'key': 'work_selection',
        'label': '工作选择',
        'value': activityData.work_selection,
      },
      {'key': 'work_style', 'label': '工作风格', 'value': activityData.work_style},
    ];

    for (var field in allFields) {
      if (field['value'] != null && field['value'].toString().isNotEmpty) {
        detailWidgets.add(
          _buildDetailCard(
            field['label'] as String,
            field['value'].toString(),
            field['key'] as String,
          ),
        );
      }
    }

    if (detailWidgets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '暂无详细数据',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFE5ECFF),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(children: detailWidgets),
      ),
    );
  }

  // 构建单个详细卡片
  Widget _buildDetailCard(String title, String content, String fieldKey) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF7EA1FF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7EA1FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD7D6E8), width: 1),
            ),
            child: _isEditing && _editControllers.containsKey(fieldKey)
                ? TextField(
                    controller: _editControllers[fieldKey],
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E2E2E),
                      height: 1.5,
                    ),
                  )
                : Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E2E2E),
                      height: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
