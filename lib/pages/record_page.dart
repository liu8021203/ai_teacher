import 'dart:async';
import 'dart:io';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/model/student_data_confirm_list_entity.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/pages/dialog/student_data_confirm_dialog.dart';
import 'package:ai_teacher/pages/student_detail_page.dart';
import 'package:ai_teacher/util/app_util.dart';
import 'package:ai_teacher/util/event_bus.dart';
import 'package:ai_teacher/util/sp_util.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  List<StudentListEntity>? _studentList = null;
  double _studentWidth = 0;
  double _studentHeight = 0;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isCancelling = false; // 是否正在取消录音状态

  // 未读数据相关
  List<StudentDataConfirmListEntity> _unreadDataList = [];
  Map<int, int> _studentUnreadCount = {}; // 学生ID -> 未读数量
  int _unknownUnreadCount = 0; // 未知条目的未读数量
  Timer? _fetchUnreadDataTimer; // 延迟拉取未读数据的定时器
  StreamSubscription? _studentDataChangedSubscription; // 学生数据变更事件订阅
  StreamSubscription? _dailyAnalyzeStartedSubscription; // 日报分析开始事件订阅
  StreamSubscription? _classChangedSubscription; // 班级切换事件订阅

  @override
  void initState() {
    super.initState();
    _fetchStudentList();
    _fetchUnreadData();

    // 监听学生数据变更事件
    _studentDataChangedSubscription = eventBus
        .on<StudentDataChangedEvent>()
        .listen((event) {
          _fetchStudentList();
          _fetchUnreadData();
        });

    // 监听日报分析开始事件
    _dailyAnalyzeStartedSubscription = eventBus
        .on<DailyAnalyzeStartedEvent>()
        .listen((event) {
          debugPrint('收到日报分析开始事件，刷新未读数据');
          _fetchUnreadData();
        });

    // 监听班级切换事件
    _classChangedSubscription = eventBus.on<ClassChangedEvent>().listen((
      event,
    ) {
      debugPrint('收到班级切换事件，刷新学生列表和未读数据');
      _fetchStudentList();
      _fetchUnreadData();
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _fetchUnreadDataTimer?.cancel();
    _studentDataChangedSubscription?.cancel();
    _dailyAnalyzeStartedSubscription?.cancel();
    _classChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchStudentList() async {
    try {
      final String? classId = SPUtil.getString('classId', defaultValue: null);
      debugPrint("classId : $classId");

      if (classId == null) {
        return;
      }

      List<StudentListEntity>? list = await DioClient()
          .post<List<StudentListEntity>>(
            '/studentList',
            data: {
              'token': UserManager().getUserInfo()?.token,
              'schoolId': UserManager().getUserInfo()?.schoolId,
              "classId": classId,
            },
            fromJson: (json) {
              if (json is List) {
                return json.map((e) => StudentListEntity.fromJson(e)).toList();
              }
              return null;
            },
          );

      if (mounted) {
        setState(() {
          _studentList = list;
        });
      }
    } catch (e) {
      debugPrint('获取学生列表失败: $e');
    }
  }

  Future<void> _fetchUnreadData() async {
    try {
      final String? classId = SPUtil.getString('classId', defaultValue: null);
      if (classId == null) {
        return;
      }

      List<StudentDataConfirmListEntity>? list = await DioClient()
          .post<List<StudentDataConfirmListEntity>>(
            '/getStudentDataToBeConfirmed',
            data: {'classId': classId},
            fromJson: (json) {
              if (json is List) {
                return json
                    .map((e) => StudentDataConfirmListEntity.fromJson(e))
                    .toList();
              }
              return null;
            },
          );

      if (mounted && list != null) {
        setState(() {
          _unreadDataList = list;
          _calculateUnreadCounts();
        });
      }
    } catch (e) {
      debugPrint('获取未读数据失败: $e');
    }
  }

  void _calculateUnreadCounts() {
    _studentUnreadCount.clear();
    _unknownUnreadCount = 0;

    for (var item in _unreadDataList) {
      if (item.studentId == null || item.studentId == 0) {
        // studentId 为 null 或 0 的归为未知条目
        _unknownUnreadCount++;
      } else {
        // 统计每个学生的未读数量
        _studentUnreadCount[item.studentId!] =
            (_studentUnreadCount[item.studentId!] ?? 0) + 1;
      }
    }
  }

  void _onStudentTap(int studentId, StudentListEntity? student) {
    // 获取该学生的未读数据
    List<StudentDataConfirmListEntity> studentDataList = [];

    if (studentId == 0) {
      // 未知条目
      studentDataList = _unreadDataList
          .where((item) => item.studentId == null || item.studentId == 0)
          .toList();
    } else {
      // 普通学生
      studentDataList = _unreadDataList
          .where((item) => item.studentId == studentId)
          .toList();
    }

    if (studentDataList.isEmpty) {
      // 没有未读数据，不弹出Dialog
      return;
    }

    // 显示Dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          StudentDataConfirmDialog(student: student, dataList: studentDataList),
    ).then((result) {
      if (result == true) {
        // 刷新未读数据
        _fetchUnreadData();
      }
    });
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    // 检查是否已有权限
    final currentStatus = await Permission.microphone.status;

    // 如果没有权限，先请求权限
    if (!currentStatus.isGranted) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能录音')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已授予麦克风权限，请再次长按开始录音')));
      }
      return;
    }

    // 已有权限，开始录音
    try {
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/record_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
      });

      debugPrint('开始录音: $filePath');
    } catch (e) {
      debugPrint('录音失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('录音失败: $e')));
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });

      debugPrint('录音结束: $path');

      if (path != null && path.isNotEmpty) {
        _uploadAudio(path);
      }
    } catch (e) {
      debugPrint('停止录音失败: $e');
      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });

      debugPrint('录音已取消: $path');

      // 删除录音文件
      if (path != null && path.isNotEmpty) {
        _deleteAudioFile(path);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('录音已取消'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      debugPrint('取消录音失败: $e');
      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });
    }
  }

  Future<void> _uploadAudio(String filePath) async {
    context.loaderOverlay.show();

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('录音文件不存在');
      }

      MultipartFile audioFile = await MultipartFile.fromFile(
        filePath,
        filename: 'audio.m4a',
      );
      final String? classId = SPUtil.getString('classId', defaultValue: null);

      await DioClient().post(
        '/aiAnalyzeRecordAudio',
        data: FormData.fromMap({
          'token': UserManager().getUserInfo()?.token,
          'classId': classId,
          'audioFile': audioFile,
        }),
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('上传成功')));

        // 删除音频文件
        _deleteAudioFile(filePath);

        // 启动延迟拉取未读数据的定时器（30秒后执行）
        _startFetchUnreadDataTimer();
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();

        // 显示重试对话框
        _showRetryDialog(filePath);
      }
    }
  }

  void _showRetryDialog(String filePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('上传失败'),
          content: const Text('音频上传失败，是否重试？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAudioFile(filePath);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _uploadAudio(filePath);
              },
              child: const Text('重试'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAudioFile(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('音频文件已删除: $filePath');
      }
    } catch (e) {
      debugPrint('删除音频文件失败: $e');
    }
  }

  void _startFetchUnreadDataTimer() {
    // 如果已有定时器在运行，先取消
    _fetchUnreadDataTimer?.cancel();

    // 创建新的30秒定时器
    _fetchUnreadDataTimer = Timer(const Duration(seconds: 10), () {
      debugPrint('10秒后自动拉取未读数据');
      _fetchUnreadData();
    });

    debugPrint('启动10秒延迟拉取未读数据定时器');
  }

  @override
  Widget build(BuildContext context) {
    _studentWidth = (MediaQuery.of(context).size.width - 16 - 12 * 4) / 9 * 2;
    _studentHeight =
        AppUtil.calculateTextWidth(
          "小明",
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ) +
        _studentWidth +
        6 +
        8;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '观察记录',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF82A6F5),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            height: _studentHeight,
            margin: EdgeInsets.fromLTRB(0, 16, 0, 0),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                // 判断是否是最后一个（未知条目）
                final isUnknown = index == (_studentList?.length ?? 0);
                final studentId = isUnknown ? 0 : _studentList![index].id;
                final unreadCount = isUnknown
                    ? _unknownUnreadCount
                    : (_studentUnreadCount[studentId] ?? 0);

                return GestureDetector(
                  onTap: () {

                    if(isUnknown){
                      if (unreadCount > 0) {
                        _onStudentTap(
                          studentId,
                          isUnknown ? null : _studentList![index],
                        );
                      }
                    }else{
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StudentDetailPage(studentId: studentId),
                        ),
                      );
                    }
                  },
                  child: Column(
                    children: [
                      badges.Badge(
                        position: badges.BadgePosition.bottomEnd(
                          bottom: -10,
                          end: -3,
                        ),
                        showBadge: unreadCount > 0,
                        ignorePointer: false,
                        onTap: () {},
                        badgeContent: Text(
                          '$unreadCount',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        badgeStyle: badges.BadgeStyle(
                          shape: badges.BadgeShape.circle,
                          badgeColor: getStudentDataColor(
                            isUnknown ? 0 : _studentList![index].id,
                          ),
                          padding: EdgeInsets.all(5),
                          borderSide: BorderSide(color: Colors.white, width: 2),
                          elevation: 0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: isUnknown
                              ? Container(
                                  width: _studentWidth,
                                  height: _studentWidth,
                                  color: Colors.grey.shade300,
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl:
                                      _studentList![index].studentAvatar ?? "",
                                  width: _studentWidth,
                                  height: _studentWidth,
                                  maxHeightDiskCache: 300,
                                  maxWidthDiskCache: 300,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.shade300,
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: Colors.grey.shade300,
                                        child: Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        width: _studentWidth,
                        alignment: Alignment.center,
                        child: Text(
                          isUnknown ? '未知' : _studentList![index].studentName,
                          style: TextStyle(
                            overflow: TextOverflow.ellipsis,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) {
                return SizedBox(width: 12);
              },
              itemCount: (_studentList?.length ?? 0) + 1, // +1 为未知条目
            ),
          ),

          const Spacer(flex: 2),

          // 取消录音区域（录音时显示在按钮上方）
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _isCancelling
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isCancelling
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFFE0E0E0),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      color: _isCancelling
                          ? Colors.white
                          : const Color(0xFF999999),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '上移取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _isCancelling
                            ? Colors.white
                            : const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!_isRecording) const Spacer(flex: 1),

          // 底部录音按钮区域
          Column(
            children: [
              // 蓝色圆形按钮
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressMoveUpdate: (details) {
                  if (!_isRecording) return;

                  // 获取全局坐标
                  final globalPosition = details.globalPosition;

                  // 计算取消区域的位置
                  // 取消按钮在屏幕中间偏上的位置
                  final screenHeight = MediaQuery.of(context).size.height;
                  final screenWidth = MediaQuery.of(context).size.width;

                  // 取消区域的大致位置（根据UI布局估算）
                  // 距离顶部约 40-50% 的位置
                  final cancelAreaTop = screenHeight * 0.35;
                  final cancelAreaBottom = screenHeight * 0.5;
                  final cancelAreaLeft = screenWidth * 0.2;
                  final cancelAreaRight = screenWidth * 0.8;

                  // 判断手指是否在取消区域内
                  final isInCancelArea =
                      globalPosition.dy >= cancelAreaTop &&
                      globalPosition.dy <= cancelAreaBottom &&
                      globalPosition.dx >= cancelAreaLeft &&
                      globalPosition.dx <= cancelAreaRight;

                  if (isInCancelArea && !_isCancelling) {
                    setState(() {
                      _isCancelling = true;
                    });
                  } else if (!isInCancelArea && _isCancelling) {
                    setState(() {
                      _isCancelling = false;
                    });
                  }
                },
                onLongPressEnd: (_) {
                  if (_isCancelling) {
                    _cancelRecording();
                  } else {
                    _stopRecording();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 174 : 154,
                  height: _isRecording ? 174 : 154,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF82A6F5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isRecording
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF82A6F5))
                                .withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: _isRecording ? 50 : 40,
                  ),
                ),
              ),
              const SizedBox(height: 34),
              // 底部文字（保持两行避免布局跳动）
              Text(
                _isRecording ? '松开\n发送' : '长按按钮\n进行观察记录',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2E2E2E),
                  fontWeight: FontWeight.w400,
                  height: 1.4, // 行高
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Color getStudentDataColor(int studentId) {
    int count = _studentUnreadCount[studentId] ?? 0;
    if (count < 5) {
      return Color(0xFF44588D);
    } else if (count >= 5 && count < 10) {
      return Color(0xFF7EA1FF);
    } else if (count >= 10) {
      return Color(0xFFBED0FF);
    } else {
      return Color(0xFF44588D);
    }
  }
}
