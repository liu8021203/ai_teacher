import 'package:flutter/material.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('活动'),
        centerTitle: true,
        backgroundColor: const Color(0xFF7B9EFF),
      ),
      body: const Center(child: Text('活动页面内容')),
    );
  }
}


