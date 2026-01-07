// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_analyze_result_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyAnalyzeResultEntity _$DailyAnalyzeResultEntityFromJson(
  Map<String, dynamic> json,
) => DailyAnalyzeResultEntity(
  summary: json['summary'] as String?,
  analyzeData: (json['analyzeData'] as List<dynamic>?)
      ?.map((e) => DailyAnalyzeListEntity.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DailyAnalyzeResultEntityToJson(
  DailyAnalyzeResultEntity instance,
) => <String, dynamic>{
  'summary': instance.summary,
  'analyzeData': instance.analyzeData,
};
