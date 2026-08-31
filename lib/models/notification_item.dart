import 'package:flutter/material.dart';

class NotificationItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const NotificationItem(
      {required this.title, required this.subtitle, required this.icon, required this.iconColor});
}