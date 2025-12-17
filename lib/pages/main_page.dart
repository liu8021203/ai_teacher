import 'package:ai_teacher/pages/dialog/class_selection_dialog.dart';
import 'package:ai_teacher/util/sp_util.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../http/core/dio_client.dart';
import '../http/model/class_list_entity.dart';
import '../manager/user_manager.dart';
import 'record_page.dart';
import 'activity_page.dart';
import 'class_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [const RecordPage(), const ActivityPage(), ClassPage()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClassSelection();
    });
  }

  Future<void> _checkClassSelection() async {
    final String? classId = SPUtil.getString('classId', defaultValue: null);
    if (classId == null || classId.isEmpty) {
      if (mounted) {
        _showClassSelectionDialog();
      }
    }
  }

  void _showClassSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const ClassSelectionDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF82A6F5),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: '记录'),
          BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), label: '活动'),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            label: '班级',
          ),
        ],
      ),
    );
  }
}
