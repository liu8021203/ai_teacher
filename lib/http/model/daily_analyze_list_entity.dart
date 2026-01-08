import 'package:json_annotation/json_annotation.dart';

part 'daily_analyze_list_entity.g.dart';

@JsonSerializable()
class DailyAnalyzeListEntity {
  late final int id;
  late final int summary_id;
  late String? activity_name;
  late String? action;
  late String? error_control;
  late String? finish;
  late String? give_up;
  late String? interaction;
  late String? layout;
  late String? operation;
  late String? paralanguage;
  late String? persist;
  late String? repeat;
  late String? sequence;
  late String? social;
  late String? speech;
  late String? work_dur;
  late String? work_selection;
  late String? work_style;

  DailyAnalyzeListEntity({
    required this.summary_id,
    this.activity_name,
    this.action,
    this.error_control,
    this.finish,
    this.give_up,
    this.interaction,
    this.layout,
    this.operation,
    this.paralanguage,
    this.persist,
    this.repeat,
    this.sequence,
    this.social,
    this.speech,
    this.work_dur,
    this.work_selection,
    this.work_style,
  });

  factory DailyAnalyzeListEntity.fromJson(Map<String, dynamic> json) =>
      _$DailyAnalyzeListEntityFromJson(json);

  Map<String, dynamic> toJson() => _$DailyAnalyzeListEntityToJson(this);
}
