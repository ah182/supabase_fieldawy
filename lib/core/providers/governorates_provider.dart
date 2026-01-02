import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fieldawy_store/core/models/governorate_model.dart';

final governoratesProvider = FutureProvider<List<GovernorateModel>>((ref) async {
  final String response = await rootBundle.loadString('assets/governorates.json');
  final List<dynamic> data = json.decode(response);
  return data.map((json) => GovernorateModel.fromJson(json)).toList();
});
