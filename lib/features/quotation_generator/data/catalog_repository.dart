// lib/features/quotation_generator/data/catalog_repository.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/heat_pump_model.dart';
import '../models/pool_heat_pump_model.dart';
import '../models/all_in_one_model.dart';

class CatalogRepository {
  static List<HeatPumpModel>? _cachedBundledModels;
  static List<PoolHeatPumpModel>? _cachedPoolModels;
  static List<AllInOneModel>? _cachedAllInOneModels;
  static Map<String, dynamic>? _cachedTankPresets;

  static Future<List<HeatPumpModel>> loadBundledModels() async {
    if (_cachedBundledModels != null) return _cachedBundledModels!;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/heat_pump_models.json');
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _cachedBundledModels = list
          .map((e) => HeatPumpModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return _cachedBundledModels!;
    } catch (e) {
      // Fallback seed with IZ-4C if file read fails
      _cachedBundledModels = [
        const HeatPumpModel(
          id: 'IZ-4C',
          modelName: 'IZ-4C',
          displayCapacityKw: 4.0,
          ratedHeatingCapacity: '3.6kw',
          descriptionLine: 'Air Source Heat pump 3.6kw',
          makeModelLine: 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw',
          powerInputText: 'Power Input 0.86kw, output 3.6kw, 220V - 1Phase, 50Hz With Auto Defrost.',
          defaultImagePath: 'assets/images/model_iz_4c.png',
          specs: {
            'Size (W x D x H)': '936x385x550mm',
            'Rated Heating Capacity': '3.6kw',
            'Power Supply': '220V - 1Phase',
            'Rated Input Power': '0.86kw',
            'Rated COP': '4.18',
            'Rated Water Yield': '78 L/h',
            'Max Outlet Water Temperature': '60°C',
            'Water Flow Noise': '<=47dB(A)',
            'Condenser': 'Shell and tube heat exchanger',
            'Refrigerant': 'R134A/410A',
            'Operating ambient Temp': '-15~43°C',
            'Compressor': 'SINGLE',
          },
        ),
      ];
      return _cachedBundledModels!;
    }
  }

  static Future<List<PoolHeatPumpModel>> loadBundledPoolModels() async {
    if (_cachedPoolModels != null) return _cachedPoolModels!;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/pool_models.json');
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _cachedPoolModels = list
          .map((e) => PoolHeatPumpModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return _cachedPoolModels!;
    } catch (e) {
      _cachedPoolModels = [PoolHeatPumpModel.defaultModel()];
      return _cachedPoolModels!;
    }
  }

  static Future<List<AllInOneModel>> loadBundledAllInOneModels() async {
    if (_cachedAllInOneModels != null) return _cachedAllInOneModels!;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/all_in_one_models.json');
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _cachedAllInOneModels = list
          .map((e) => AllInOneModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return _cachedAllInOneModels!;
    } catch (e) {
      _cachedAllInOneModels = [
        AllInOneModel.defaultFloorModel(),
        AllInOneModel.defaultWallModel(),
      ];
      return _cachedAllInOneModels!;
    }
  }

  static Future<Map<String, dynamic>> loadBundledTankPresets() async {
    if (_cachedTankPresets != null) return _cachedTankPresets!;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/tank_presets.json');
      _cachedTankPresets = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _cachedTankPresets!;
    } catch (e) {
      return {};
    }
  }
}
