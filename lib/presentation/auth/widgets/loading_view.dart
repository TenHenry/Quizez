import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Quizez', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black)),
          SizedBox(height: 20),
          CircularProgressIndicator(color: Colors.black),
        ],
      ),
    );
  }
}