import 'package:ai_teacher/http/model/daily_analyze_list_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'daily_analyze_result_entity.g.dart';

@JsonSerializable()
class DailyAnalyzeResultEntity {
  late final String? summary;
  late final List<DailyAnalyzeListEntity>? analyzeData;

  DailyAnalyzeResultEntity({
    this.summary,
    this.analyzeData
  });

  factory DailyAnalyzeResultEntity.fromJson(Map<String, dynamic> json) => _$DailyAnalyzeResultEntityFromJson(json);

  Map<String, dynamic> toJson() => _$DailyAnalyzeResultEntityToJson(this);
}
