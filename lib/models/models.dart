import 'package:flutter/material.dart';

class MembershipPlan {
  String name;
  double price;
  String description;
  int activeMembers;
  Color badgeColor;
  Color badgeTextColor;

  MembershipPlan({
    required this.name,
    required this.price,
    required this.description,
    required this.activeMembers,
    required this.badgeColor,
    required this.badgeTextColor,
  });
}

enum PaymentStatus { paid, pending, failed }

class Payment {
  final String member;
  final String plan;
  final double amount;
  final String method;
  final String date;
  final PaymentStatus status;

  Payment({
    required this.member,
    required this.plan,
    required this.amount,
    required this.method,
    required this.date,
    required this.status,
  });
}
