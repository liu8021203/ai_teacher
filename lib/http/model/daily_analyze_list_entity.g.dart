// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_analyze_list_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyAnalyzeListEntity _$DailyAnalyzeListEntityFromJson(
  Map<String, dynamic> json,
) => DailyAnalyzeListEntity(
  summary_id: (json['summary_id'] as num).toInt(),
  activity_name: json['activity_name'] as String?,
  action: json['action'] as String?,
  error_control: json['error_control'] as String?,
  finish: json['finish'] as String?,
  give_up: json['give_up'] as String?,
  interaction: json['interaction'] as String?,
  layout: json['layout'] as String?,
  operation: json['operation'] as String?,
  paralanguage: json['paralanguage'] as String?,
  persist: json['persist'] as String?,
  repeat: json['repeat'] as String?,
  sequence: json['sequence'] as String?,
  social: json['social'] as String?,
  speech: json['speech'] as String?,
  work_dur: json['work_dur'] as String?,
  work_selection: json['work_selection'] as String?,
  work_style: json['work_style'] as String?,
)..id = (json['id'] as num).toInt();

Map<String, dynamic> _$DailyAnalyzeListEntityToJson(
  DailyAnalyzeListEntity instance,
) => <String, dynamic>{
  'id': instance.id,
  'summary_id': instance.summary_id,
  'activity_name': instance.activity_name,
  'action': instance.action,
  'error_control': instance.error_control,
  'finish': instance.finish,
  'give_up': instance.give_up,
  'interaction': instance.interaction,
  'layout': instance.layout,
  'operation': instance.operation,
  'paralanguage': instance.paralanguage,
  'persist': instance.persist,
  'repeat': instance.repeat,
  'sequence': instance.sequence,
  'social': instance.social,
  'speech': instance.speech,
  'work_dur': instance.work_dur,
  'work_selection': instance.work_selection,
  'work_style': instance.work_style,
};
