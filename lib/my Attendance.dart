import 'package:flutter/material.dart';

class MyAttendancePage extends StatelessWidget {
  const MyAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
      ),
      body: Center(
        child: Text(
          'Attendance details will be displayed here.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
