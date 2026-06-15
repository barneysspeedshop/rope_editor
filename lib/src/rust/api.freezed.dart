// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AgentResponse {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<EditorAction> edits, String message)
        applyEdits,
    required TResult Function(String message) clarify,
    required TResult Function(String summary) summarize,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<EditorAction> edits, String message)? applyEdits,
    TResult? Function(String message)? clarify,
    TResult? Function(String summary)? summarize,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<EditorAction> edits, String message)? applyEdits,
    TResult Function(String message)? clarify,
    TResult Function(String summary)? summarize,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AgentResponse_ApplyEdits value) applyEdits,
    required TResult Function(AgentResponse_Clarify value) clarify,
    required TResult Function(AgentResponse_Summarize value) summarize,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AgentResponse_ApplyEdits value)? applyEdits,
    TResult? Function(AgentResponse_Clarify value)? clarify,
    TResult? Function(AgentResponse_Summarize value)? summarize,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AgentResponse_ApplyEdits value)? applyEdits,
    TResult Function(AgentResponse_Clarify value)? clarify,
    TResult Function(AgentResponse_Summarize value)? summarize,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentResponseCopyWith<$Res> {
  factory $AgentResponseCopyWith(
          AgentResponse value, $Res Function(AgentResponse) then) =
      _$AgentResponseCopyWithImpl<$Res, AgentResponse>;
}

/// @nodoc
class _$AgentResponseCopyWithImpl<$Res, $Val extends AgentResponse>
    implements $AgentResponseCopyWith<$Res> {
  _$AgentResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$AgentResponse_ApplyEditsImplCopyWith<$Res> {
  factory _$$AgentResponse_ApplyEditsImplCopyWith(
          _$AgentResponse_ApplyEditsImpl value,
          $Res Function(_$AgentResponse_ApplyEditsImpl) then) =
      __$$AgentResponse_ApplyEditsImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<EditorAction> edits, String message});
}

/// @nodoc
class __$$AgentResponse_ApplyEditsImplCopyWithImpl<$Res>
    extends _$AgentResponseCopyWithImpl<$Res, _$AgentResponse_ApplyEditsImpl>
    implements _$$AgentResponse_ApplyEditsImplCopyWith<$Res> {
  __$$AgentResponse_ApplyEditsImplCopyWithImpl(
      _$AgentResponse_ApplyEditsImpl _value,
      $Res Function(_$AgentResponse_ApplyEditsImpl) _then)
      : super(_value, _then);

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? edits = null,
    Object? message = null,
  }) {
    return _then(_$AgentResponse_ApplyEditsImpl(
      edits: null == edits
          ? _value._edits
          : edits // ignore: cast_nullable_to_non_nullable
              as List<EditorAction>,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$AgentResponse_ApplyEditsImpl extends AgentResponse_ApplyEdits {
  const _$AgentResponse_ApplyEditsImpl(
      {required final List<EditorAction> edits, required this.message})
      : _edits = edits,
        super._();

  final List<EditorAction> _edits;
  @override
  List<EditorAction> get edits {
    if (_edits is EqualUnmodifiableListView) return _edits;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_edits);
  }

  /// Conversational reply for the agent REPL in the same turn.
  @override
  final String message;

  @override
  String toString() {
    return 'AgentResponse.applyEdits(edits: $edits, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentResponse_ApplyEditsImpl &&
            const DeepCollectionEquality().equals(other._edits, _edits) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_edits), message);

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentResponse_ApplyEditsImplCopyWith<_$AgentResponse_ApplyEditsImpl>
      get copyWith => __$$AgentResponse_ApplyEditsImplCopyWithImpl<
          _$AgentResponse_ApplyEditsImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<EditorAction> edits, String message)
        applyEdits,
    required TResult Function(String message) clarify,
    required TResult Function(String summary) summarize,
  }) {
    return applyEdits(edits, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<EditorAction> edits, String message)? applyEdits,
    TResult? Function(String message)? clarify,
    TResult? Function(String summary)? summarize,
  }) {
    return applyEdits?.call(edits, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<EditorAction> edits, String message)? applyEdits,
    TResult Function(String message)? clarify,
    TResult Function(String summary)? summarize,
    required TResult orElse(),
  }) {
    if (applyEdits != null) {
      return applyEdits(edits, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AgentResponse_ApplyEdits value) applyEdits,
    required TResult Function(AgentResponse_Clarify value) clarify,
    required TResult Function(AgentResponse_Summarize value) summarize,
  }) {
    return applyEdits(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AgentResponse_ApplyEdits value)? applyEdits,
    TResult? Function(AgentResponse_Clarify value)? clarify,
    TResult? Function(AgentResponse_Summarize value)? summarize,
  }) {
    return applyEdits?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AgentResponse_ApplyEdits value)? applyEdits,
    TResult Function(AgentResponse_Clarify value)? clarify,
    TResult Function(AgentResponse_Summarize value)? summarize,
    required TResult orElse(),
  }) {
    if (applyEdits != null) {
      return applyEdits(this);
    }
    return orElse();
  }
}

abstract class AgentResponse_ApplyEdits extends AgentResponse {
  const factory AgentResponse_ApplyEdits(
      {required final List<EditorAction> edits,
      required final String message}) = _$AgentResponse_ApplyEditsImpl;
  const AgentResponse_ApplyEdits._() : super._();

  List<EditorAction> get edits;

  /// Conversational reply for the agent REPL in the same turn.
  String get message;

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentResponse_ApplyEditsImplCopyWith<_$AgentResponse_ApplyEditsImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AgentResponse_ClarifyImplCopyWith<$Res> {
  factory _$$AgentResponse_ClarifyImplCopyWith(
          _$AgentResponse_ClarifyImpl value,
          $Res Function(_$AgentResponse_ClarifyImpl) then) =
      __$$AgentResponse_ClarifyImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$AgentResponse_ClarifyImplCopyWithImpl<$Res>
    extends _$AgentResponseCopyWithImpl<$Res, _$AgentResponse_ClarifyImpl>
    implements _$$AgentResponse_ClarifyImplCopyWith<$Res> {
  __$$AgentResponse_ClarifyImplCopyWithImpl(_$AgentResponse_ClarifyImpl _value,
      $Res Function(_$AgentResponse_ClarifyImpl) _then)
      : super(_value, _then);

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$AgentResponse_ClarifyImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$AgentResponse_ClarifyImpl extends AgentResponse_Clarify {
  const _$AgentResponse_ClarifyImpl({required this.message}) : super._();

  @override
  final String message;

  @override
  String toString() {
    return 'AgentResponse.clarify(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentResponse_ClarifyImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentResponse_ClarifyImplCopyWith<_$AgentResponse_ClarifyImpl>
      get copyWith => __$$AgentResponse_ClarifyImplCopyWithImpl<
          _$AgentResponse_ClarifyImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<EditorAction> edits, String message)
        applyEdits,
    required TResult Function(String message) clarify,
    required TResult Function(String summary) summarize,
  }) {
    return clarify(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<EditorAction> edits, String message)? applyEdits,
    TResult? Function(String message)? clarify,
    TResult? Function(String summary)? summarize,
  }) {
    return clarify?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<EditorAction> edits, String message)? applyEdits,
    TResult Function(String message)? clarify,
    TResult Function(String summary)? summarize,
    required TResult orElse(),
  }) {
    if (clarify != null) {
      return clarify(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AgentResponse_ApplyEdits value) applyEdits,
    required TResult Function(AgentResponse_Clarify value) clarify,
    required TResult Function(AgentResponse_Summarize value) summarize,
  }) {
    return clarify(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AgentResponse_ApplyEdits value)? applyEdits,
    TResult? Function(AgentResponse_Clarify value)? clarify,
    TResult? Function(AgentResponse_Summarize value)? summarize,
  }) {
    return clarify?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AgentResponse_ApplyEdits value)? applyEdits,
    TResult Function(AgentResponse_Clarify value)? clarify,
    TResult Function(AgentResponse_Summarize value)? summarize,
    required TResult orElse(),
  }) {
    if (clarify != null) {
      return clarify(this);
    }
    return orElse();
  }
}

abstract class AgentResponse_Clarify extends AgentResponse {
  const factory AgentResponse_Clarify({required final String message}) =
      _$AgentResponse_ClarifyImpl;
  const AgentResponse_Clarify._() : super._();

  String get message;

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentResponse_ClarifyImplCopyWith<_$AgentResponse_ClarifyImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AgentResponse_SummarizeImplCopyWith<$Res> {
  factory _$$AgentResponse_SummarizeImplCopyWith(
          _$AgentResponse_SummarizeImpl value,
          $Res Function(_$AgentResponse_SummarizeImpl) then) =
      __$$AgentResponse_SummarizeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String summary});
}

/// @nodoc
class __$$AgentResponse_SummarizeImplCopyWithImpl<$Res>
    extends _$AgentResponseCopyWithImpl<$Res, _$AgentResponse_SummarizeImpl>
    implements _$$AgentResponse_SummarizeImplCopyWith<$Res> {
  __$$AgentResponse_SummarizeImplCopyWithImpl(
      _$AgentResponse_SummarizeImpl _value,
      $Res Function(_$AgentResponse_SummarizeImpl) _then)
      : super(_value, _then);

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? summary = null,
  }) {
    return _then(_$AgentResponse_SummarizeImpl(
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$AgentResponse_SummarizeImpl extends AgentResponse_Summarize {
  const _$AgentResponse_SummarizeImpl({required this.summary}) : super._();

  @override
  final String summary;

  @override
  String toString() {
    return 'AgentResponse.summarize(summary: $summary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentResponse_SummarizeImpl &&
            (identical(other.summary, summary) || other.summary == summary));
  }

  @override
  int get hashCode => Object.hash(runtimeType, summary);

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentResponse_SummarizeImplCopyWith<_$AgentResponse_SummarizeImpl>
      get copyWith => __$$AgentResponse_SummarizeImplCopyWithImpl<
          _$AgentResponse_SummarizeImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<EditorAction> edits, String message)
        applyEdits,
    required TResult Function(String message) clarify,
    required TResult Function(String summary) summarize,
  }) {
    return summarize(summary);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<EditorAction> edits, String message)? applyEdits,
    TResult? Function(String message)? clarify,
    TResult? Function(String summary)? summarize,
  }) {
    return summarize?.call(summary);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<EditorAction> edits, String message)? applyEdits,
    TResult Function(String message)? clarify,
    TResult Function(String summary)? summarize,
    required TResult orElse(),
  }) {
    if (summarize != null) {
      return summarize(summary);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(AgentResponse_ApplyEdits value) applyEdits,
    required TResult Function(AgentResponse_Clarify value) clarify,
    required TResult Function(AgentResponse_Summarize value) summarize,
  }) {
    return summarize(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(AgentResponse_ApplyEdits value)? applyEdits,
    TResult? Function(AgentResponse_Clarify value)? clarify,
    TResult? Function(AgentResponse_Summarize value)? summarize,
  }) {
    return summarize?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(AgentResponse_ApplyEdits value)? applyEdits,
    TResult Function(AgentResponse_Clarify value)? clarify,
    TResult Function(AgentResponse_Summarize value)? summarize,
    required TResult orElse(),
  }) {
    if (summarize != null) {
      return summarize(this);
    }
    return orElse();
  }
}

abstract class AgentResponse_Summarize extends AgentResponse {
  const factory AgentResponse_Summarize({required final String summary}) =
      _$AgentResponse_SummarizeImpl;
  const AgentResponse_Summarize._() : super._();

  String get summary;

  /// Create a copy of AgentResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentResponse_SummarizeImplCopyWith<_$AgentResponse_SummarizeImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$OrchestrateEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) thinking,
    required TResult Function(String delta) editDelta,
    required TResult Function(List<FileReference> files, String message)
        contextWindowUpdate,
    required TResult Function(AgentContextBudget budget) contextBudgetUpdate,
    required TResult Function(AgentResponse response) complete,
    required TResult Function(String message) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? thinking,
    TResult? Function(String delta)? editDelta,
    TResult? Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult? Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult? Function(AgentResponse response)? complete,
    TResult? Function(String message)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? thinking,
    TResult Function(String delta)? editDelta,
    TResult Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult Function(AgentResponse response)? complete,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OrchestrateEvent_Thinking value) thinking,
    required TResult Function(OrchestrateEvent_EditDelta value) editDelta,
    required TResult Function(OrchestrateEvent_ContextWindowUpdate value)
        contextWindowUpdate,
    required TResult Function(OrchestrateEvent_ContextBudgetUpdate value)
        contextBudgetUpdate,
    required TResult Function(OrchestrateEvent_Complete value) complete,
    required TResult Function(OrchestrateEvent_Error value) error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OrchestrateEvent_Thinking value)? thinking,
    TResult? Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult? Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult? Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult? Function(OrchestrateEvent_Complete value)? complete,
    TResult? Function(OrchestrateEvent_Error value)? error,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OrchestrateEvent_Thinking value)? thinking,
    TResult Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult Function(OrchestrateEvent_Complete value)? complete,
    TResult Function(OrchestrateEvent_Error value)? error,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrchestrateEventCopyWith<$Res> {
  factory $OrchestrateEventCopyWith(
          OrchestrateEvent value, $Res Function(OrchestrateEvent) then) =
      _$OrchestrateEventCopyWithImpl<$Res, OrchestrateEvent>;
}

/// @nodoc
class _$OrchestrateEventCopyWithImpl<$Res, $Val extends OrchestrateEvent>
    implements $OrchestrateEventCopyWith<$Res> {
  _$OrchestrateEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$OrchestrateEvent_ThinkingImplCopyWith<$Res> {
  factory _$$OrchestrateEvent_ThinkingImplCopyWith(
          _$OrchestrateEvent_ThinkingImpl value,
          $Res Function(_$OrchestrateEvent_ThinkingImpl) then) =
      __$$OrchestrateEvent_ThinkingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String text});
}

/// @nodoc
class __$$OrchestrateEvent_ThinkingImplCopyWithImpl<$Res>
    extends _$OrchestrateEventCopyWithImpl<$Res,
        _$OrchestrateEvent_ThinkingImpl>
    implements _$$OrchestrateEvent_ThinkingImplCopyWith<$Res> {
  __$$OrchestrateEvent_ThinkingImplCopyWithImpl(
      _$OrchestrateEvent_ThinkingImpl _value,
      $Res Function(_$OrchestrateEvent_ThinkingImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
  }) {
    return _then(_$OrchestrateEvent_ThinkingImpl(
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$OrchestrateEvent_ThinkingImpl extends OrchestrateEvent_Thinking {
  const _$OrchestrateEvent_ThinkingImpl({required this.text}) : super._();

  @override
  final String text;

  @override
  String toString() {
    return 'OrchestrateEvent.thinking(text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrchestrateEvent_ThinkingImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrchestrateEvent_ThinkingImplCopyWith<_$OrchestrateEvent_ThinkingImpl>
      get copyWith => __$$OrchestrateEvent_ThinkingImplCopyWithImpl<
          _$OrchestrateEvent_ThinkingImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) thinking,
    required TResult Function(String delta) editDelta,
    required TResult Function(List<FileReference> files, String message)
        contextWindowUpdate,
    required TResult Function(AgentContextBudget budget) contextBudgetUpdate,
    required TResult Function(AgentResponse response) complete,
    required TResult Function(String message) error,
  }) {
    return thinking(text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? thinking,
    TResult? Function(String delta)? editDelta,
    TResult? Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult? Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult? Function(AgentResponse response)? complete,
    TResult? Function(String message)? error,
  }) {
    return thinking?.call(text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? thinking,
    TResult Function(String delta)? editDelta,
    TResult Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult Function(AgentResponse response)? complete,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (thinking != null) {
      return thinking(text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OrchestrateEvent_Thinking value) thinking,
    required TResult Function(OrchestrateEvent_EditDelta value) editDelta,
    required TResult Function(OrchestrateEvent_ContextWindowUpdate value)
        contextWindowUpdate,
    required TResult Function(OrchestrateEvent_ContextBudgetUpdate value)
        contextBudgetUpdate,
    required TResult Function(OrchestrateEvent_Complete value) complete,
    required TResult Function(OrchestrateEvent_Error value) error,
  }) {
    return thinking(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OrchestrateEvent_Thinking value)? thinking,
    TResult? Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult? Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult? Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult? Function(OrchestrateEvent_Complete value)? complete,
    TResult? Function(OrchestrateEvent_Error value)? error,
  }) {
    return thinking?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OrchestrateEvent_Thinking value)? thinking,
    TResult Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult Function(OrchestrateEvent_Complete value)? complete,
    TResult Function(OrchestrateEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (thinking != null) {
      return thinking(this);
    }
    return orElse();
  }
}

abstract class OrchestrateEvent_Thinking extends OrchestrateEvent {
  const factory OrchestrateEvent_Thinking({required final String text}) =
      _$OrchestrateEvent_ThinkingImpl;
  const OrchestrateEvent_Thinking._() : super._();

  String get text;

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrchestrateEvent_ThinkingImplCopyWith<_$OrchestrateEvent_ThinkingImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$OrchestrateEvent_EditDeltaImplCopyWith<$Res> {
  factory _$$OrchestrateEvent_EditDeltaImplCopyWith(
          _$OrchestrateEvent_EditDeltaImpl value,
          $Res Function(_$OrchestrateEvent_EditDeltaImpl) then) =
      __$$OrchestrateEvent_EditDeltaImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String delta});
}

/// @nodoc
class __$$OrchestrateEvent_EditDeltaImplCopyWithImpl<$Res>
    extends _$OrchestrateEventCopyWithImpl<$Res,
        _$OrchestrateEvent_EditDeltaImpl>
    implements _$$OrchestrateEvent_EditDeltaImplCopyWith<$Res> {
  __$$OrchestrateEvent_EditDeltaImplCopyWithImpl(
      _$OrchestrateEvent_EditDeltaImpl _value,
      $Res Function(_$OrchestrateEvent_EditDeltaImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? delta = null,
  }) {
    return _then(_$OrchestrateEvent_EditDeltaImpl(
      delta: null == delta
          ? _value.delta
          : delta // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$OrchestrateEvent_EditDeltaImpl extends OrchestrateEvent_EditDelta {
  const _$OrchestrateEvent_EditDeltaImpl({required this.delta}) : super._();

  @override
  final String delta;

  @override
  String toString() {
    return 'OrchestrateEvent.editDelta(delta: $delta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrchestrateEvent_EditDeltaImpl &&
            (identical(other.delta, delta) || other.delta == delta));
  }

  @override
  int get hashCode => Object.hash(runtimeType, delta);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrchestrateEvent_EditDeltaImplCopyWith<_$OrchestrateEvent_EditDeltaImpl>
      get copyWith => __$$OrchestrateEvent_EditDeltaImplCopyWithImpl<
          _$OrchestrateEvent_EditDeltaImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) thinking,
    required TResult Function(String delta) editDelta,
    required TResult Function(List<FileReference> files, String message)
        contextWindowUpdate,
    required TResult Function(AgentContextBudget budget) contextBudgetUpdate,
    required TResult Function(AgentResponse response) complete,
    required TResult Function(String message) error,
  }) {
    return editDelta(delta);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? thinking,
    TResult? Function(String delta)? editDelta,
    TResult? Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult? Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult? Function(AgentResponse response)? complete,
    TResult? Function(String message)? error,
  }) {
    return editDelta?.call(delta);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? thinking,
    TResult Function(String delta)? editDelta,
    TResult Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult Function(AgentResponse response)? complete,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (editDelta != null) {
      return editDelta(delta);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OrchestrateEvent_Thinking value) thinking,
    required TResult Function(OrchestrateEvent_EditDelta value) editDelta,
    required TResult Function(OrchestrateEvent_ContextWindowUpdate value)
        contextWindowUpdate,
    required TResult Function(OrchestrateEvent_ContextBudgetUpdate value)
        contextBudgetUpdate,
    required TResult Function(OrchestrateEvent_Complete value) complete,
    required TResult Function(OrchestrateEvent_Error value) error,
  }) {
    return editDelta(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OrchestrateEvent_Thinking value)? thinking,
    TResult? Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult? Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult? Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult? Function(OrchestrateEvent_Complete value)? complete,
    TResult? Function(OrchestrateEvent_Error value)? error,
  }) {
    return editDelta?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OrchestrateEvent_Thinking value)? thinking,
    TResult Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult Function(OrchestrateEvent_Complete value)? complete,
    TResult Function(OrchestrateEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (editDelta != null) {
      return editDelta(this);
    }
    return orElse();
  }
}

abstract class OrchestrateEvent_EditDelta extends OrchestrateEvent {
  const factory OrchestrateEvent_EditDelta({required final String delta}) =
      _$OrchestrateEvent_EditDeltaImpl;
  const OrchestrateEvent_EditDelta._() : super._();

  String get delta;

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrchestrateEvent_EditDeltaImplCopyWith<_$OrchestrateEvent_EditDeltaImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$OrchestrateEvent_ContextWindowUpdateImplCopyWith<$Res> {
  factory _$$OrchestrateEvent_ContextWindowUpdateImplCopyWith(
          _$OrchestrateEvent_ContextWindowUpdateImpl value,
          $Res Function(_$OrchestrateEvent_ContextWindowUpdateImpl) then) =
      __$$OrchestrateEvent_ContextWindowUpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<FileReference> files, String message});
}

/// @nodoc
class __$$OrchestrateEvent_ContextWindowUpdateImplCopyWithImpl<$Res>
    extends _$OrchestrateEventCopyWithImpl<$Res,
        _$OrchestrateEvent_ContextWindowUpdateImpl>
    implements _$$OrchestrateEvent_ContextWindowUpdateImplCopyWith<$Res> {
  __$$OrchestrateEvent_ContextWindowUpdateImplCopyWithImpl(
      _$OrchestrateEvent_ContextWindowUpdateImpl _value,
      $Res Function(_$OrchestrateEvent_ContextWindowUpdateImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? files = null,
    Object? message = null,
  }) {
    return _then(_$OrchestrateEvent_ContextWindowUpdateImpl(
      files: null == files
          ? _value._files
          : files // ignore: cast_nullable_to_non_nullable
              as List<FileReference>,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$OrchestrateEvent_ContextWindowUpdateImpl
    extends OrchestrateEvent_ContextWindowUpdate {
  const _$OrchestrateEvent_ContextWindowUpdateImpl(
      {required final List<FileReference> files, required this.message})
      : _files = files,
        super._();

  final List<FileReference> _files;
  @override
  List<FileReference> get files {
    if (_files is EqualUnmodifiableListView) return _files;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_files);
  }

  @override
  final String message;

  @override
  String toString() {
    return 'OrchestrateEvent.contextWindowUpdate(files: $files, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrchestrateEvent_ContextWindowUpdateImpl &&
            const DeepCollectionEquality().equals(other._files, _files) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_files), message);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrchestrateEvent_ContextWindowUpdateImplCopyWith<
          _$OrchestrateEvent_ContextWindowUpdateImpl>
      get copyWith => __$$OrchestrateEvent_ContextWindowUpdateImplCopyWithImpl<
          _$OrchestrateEvent_ContextWindowUpdateImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) thinking,
    required TResult Function(String delta) editDelta,
    required TResult Function(List<FileReference> files, String message)
        contextWindowUpdate,
    required TResult Function(AgentContextBudget budget) contextBudgetUpdate,
    required TResult Function(AgentResponse response) complete,
    required TResult Function(String message) error,
  }) {
    return contextWindowUpdate(files, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? thinking,
    TResult? Function(String delta)? editDelta,
    TResult? Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult? Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult? Function(AgentResponse response)? complete,
    TResult? Function(String message)? error,
  }) {
    return contextWindowUpdate?.call(files, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? thinking,
    TResult Function(String delta)? editDelta,
    TResult Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult Function(AgentResponse response)? complete,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (contextWindowUpdate != null) {
      return contextWindowUpdate(files, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OrchestrateEvent_Thinking value) thinking,
    required TResult Function(OrchestrateEvent_EditDelta value) editDelta,
    required TResult Function(OrchestrateEvent_ContextWindowUpdate value)
        contextWindowUpdate,
    required TResult Function(OrchestrateEvent_ContextBudgetUpdate value)
        contextBudgetUpdate,
    required TResult Function(OrchestrateEvent_Complete value) complete,
    required TResult Function(OrchestrateEvent_Error value) error,
  }) {
    return contextWindowUpdate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OrchestrateEvent_Thinking value)? thinking,
    TResult? Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult? Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult? Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult? Function(OrchestrateEvent_Complete value)? complete,
    TResult? Function(OrchestrateEvent_Error value)? error,
  }) {
    return contextWindowUpdate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OrchestrateEvent_Thinking value)? thinking,
    TResult Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult Function(OrchestrateEvent_Complete value)? complete,
    TResult Function(OrchestrateEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (contextWindowUpdate != null) {
      return contextWindowUpdate(this);
    }
    return orElse();
  }
}

abstract class OrchestrateEvent_ContextWindowUpdate extends OrchestrateEvent {
  const factory OrchestrateEvent_ContextWindowUpdate(
          {required final List<FileReference> files,
          required final String message}) =
      _$OrchestrateEvent_ContextWindowUpdateImpl;
  const OrchestrateEvent_ContextWindowUpdate._() : super._();

  List<FileReference> get files;
  String get message;

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrchestrateEvent_ContextWindowUpdateImplCopyWith<
          _$OrchestrateEvent_ContextWindowUpdateImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$OrchestrateEvent_ContextBudgetUpdateImplCopyWith<$Res> {
  factory _$$OrchestrateEvent_ContextBudgetUpdateImplCopyWith(
          _$OrchestrateEvent_ContextBudgetUpdateImpl value,
          $Res Function(_$OrchestrateEvent_ContextBudgetUpdateImpl) then) =
      __$$OrchestrateEvent_ContextBudgetUpdateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({AgentContextBudget budget});
}

/// @nodoc
class __$$OrchestrateEvent_ContextBudgetUpdateImplCopyWithImpl<$Res>
    extends _$OrchestrateEventCopyWithImpl<$Res,
        _$OrchestrateEvent_ContextBudgetUpdateImpl>
    implements _$$OrchestrateEvent_ContextBudgetUpdateImplCopyWith<$Res> {
  __$$OrchestrateEvent_ContextBudgetUpdateImplCopyWithImpl(
      _$OrchestrateEvent_ContextBudgetUpdateImpl _value,
      $Res Function(_$OrchestrateEvent_ContextBudgetUpdateImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? budget = null,
  }) {
    return _then(_$OrchestrateEvent_ContextBudgetUpdateImpl(
      budget: null == budget
          ? _value.budget
          : budget // ignore: cast_nullable_to_non_nullable
              as AgentContextBudget,
    ));
  }
}

/// @nodoc

class _$OrchestrateEvent_ContextBudgetUpdateImpl
    extends OrchestrateEvent_ContextBudgetUpdate {
  const _$OrchestrateEvent_ContextBudgetUpdateImpl({required this.budget})
      : super._();

  @override
  final AgentContextBudget budget;

  @override
  String toString() {
    return 'OrchestrateEvent.contextBudgetUpdate(budget: $budget)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrchestrateEvent_ContextBudgetUpdateImpl &&
            (identical(other.budget, budget) || other.budget == budget));
  }

  @override
  int get hashCode => Object.hash(runtimeType, budget);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrchestrateEvent_ContextBudgetUpdateImplCopyWith<
          _$OrchestrateEvent_ContextBudgetUpdateImpl>
      get copyWith => __$$OrchestrateEvent_ContextBudgetUpdateImplCopyWithImpl<
          _$OrchestrateEvent_ContextBudgetUpdateImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) thinking,
    required TResult Function(String delta) editDelta,
    required TResult Function(List<FileReference> files, String message)
        contextWindowUpdate,
    required TResult Function(AgentContextBudget budget) contextBudgetUpdate,
    required TResult Function(AgentResponse response) complete,
    required TResult Function(String message) error,
  }) {
    return contextBudgetUpdate(budget);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? thinking,
    TResult? Function(String delta)? editDelta,
    TResult? Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult? Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult? Function(AgentResponse response)? complete,
    TResult? Function(String message)? error,
  }) {
    return contextBudgetUpdate?.call(budget);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? thinking,
    TResult Function(String delta)? editDelta,
    TResult Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult Function(AgentResponse response)? complete,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (contextBudgetUpdate != null) {
      return contextBudgetUpdate(budget);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OrchestrateEvent_Thinking value) thinking,
    required TResult Function(OrchestrateEvent_EditDelta value) editDelta,
    required TResult Function(OrchestrateEvent_ContextWindowUpdate value)
        contextWindowUpdate,
    required TResult Function(OrchestrateEvent_ContextBudgetUpdate value)
        contextBudgetUpdate,
    required TResult Function(OrchestrateEvent_Complete value) complete,
    required TResult Function(OrchestrateEvent_Error value) error,
  }) {
    return contextBudgetUpdate(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OrchestrateEvent_Thinking value)? thinking,
    TResult? Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult? Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult? Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult? Function(OrchestrateEvent_Complete value)? complete,
    TResult? Function(OrchestrateEvent_Error value)? error,
  }) {
    return contextBudgetUpdate?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OrchestrateEvent_Thinking value)? thinking,
    TResult Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult Function(OrchestrateEvent_Complete value)? complete,
    TResult Function(OrchestrateEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (contextBudgetUpdate != null) {
      return contextBudgetUpdate(this);
    }
    return orElse();
  }
}

abstract class OrchestrateEvent_ContextBudgetUpdate extends OrchestrateEvent {
  const factory OrchestrateEvent_ContextBudgetUpdate(
          {required final AgentContextBudget budget}) =
      _$OrchestrateEvent_ContextBudgetUpdateImpl;
  const OrchestrateEvent_ContextBudgetUpdate._() : super._();

  AgentContextBudget get budget;

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrchestrateEvent_ContextBudgetUpdateImplCopyWith<
          _$OrchestrateEvent_ContextBudgetUpdateImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$OrchestrateEvent_CompleteImplCopyWith<$Res> {
  factory _$$OrchestrateEvent_CompleteImplCopyWith(
          _$OrchestrateEvent_CompleteImpl value,
          $Res Function(_$OrchestrateEvent_CompleteImpl) then) =
      __$$OrchestrateEvent_CompleteImplCopyWithImpl<$Res>;
  @useResult
  $Res call({AgentResponse response});

  $AgentResponseCopyWith<$Res> get response;
}

/// @nodoc
class __$$OrchestrateEvent_CompleteImplCopyWithImpl<$Res>
    extends _$OrchestrateEventCopyWithImpl<$Res,
        _$OrchestrateEvent_CompleteImpl>
    implements _$$OrchestrateEvent_CompleteImplCopyWith<$Res> {
  __$$OrchestrateEvent_CompleteImplCopyWithImpl(
      _$OrchestrateEvent_CompleteImpl _value,
      $Res Function(_$OrchestrateEvent_CompleteImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? response = null,
  }) {
    return _then(_$OrchestrateEvent_CompleteImpl(
      response: null == response
          ? _value.response
          : response // ignore: cast_nullable_to_non_nullable
              as AgentResponse,
    ));
  }

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AgentResponseCopyWith<$Res> get response {
    return $AgentResponseCopyWith<$Res>(_value.response, (value) {
      return _then(_value.copyWith(response: value));
    });
  }
}

/// @nodoc

class _$OrchestrateEvent_CompleteImpl extends OrchestrateEvent_Complete {
  const _$OrchestrateEvent_CompleteImpl({required this.response}) : super._();

  @override
  final AgentResponse response;

  @override
  String toString() {
    return 'OrchestrateEvent.complete(response: $response)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrchestrateEvent_CompleteImpl &&
            (identical(other.response, response) ||
                other.response == response));
  }

  @override
  int get hashCode => Object.hash(runtimeType, response);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrchestrateEvent_CompleteImplCopyWith<_$OrchestrateEvent_CompleteImpl>
      get copyWith => __$$OrchestrateEvent_CompleteImplCopyWithImpl<
          _$OrchestrateEvent_CompleteImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) thinking,
    required TResult Function(String delta) editDelta,
    required TResult Function(List<FileReference> files, String message)
        contextWindowUpdate,
    required TResult Function(AgentContextBudget budget) contextBudgetUpdate,
    required TResult Function(AgentResponse response) complete,
    required TResult Function(String message) error,
  }) {
    return complete(response);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? thinking,
    TResult? Function(String delta)? editDelta,
    TResult? Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult? Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult? Function(AgentResponse response)? complete,
    TResult? Function(String message)? error,
  }) {
    return complete?.call(response);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? thinking,
    TResult Function(String delta)? editDelta,
    TResult Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult Function(AgentResponse response)? complete,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (complete != null) {
      return complete(response);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OrchestrateEvent_Thinking value) thinking,
    required TResult Function(OrchestrateEvent_EditDelta value) editDelta,
    required TResult Function(OrchestrateEvent_ContextWindowUpdate value)
        contextWindowUpdate,
    required TResult Function(OrchestrateEvent_ContextBudgetUpdate value)
        contextBudgetUpdate,
    required TResult Function(OrchestrateEvent_Complete value) complete,
    required TResult Function(OrchestrateEvent_Error value) error,
  }) {
    return complete(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OrchestrateEvent_Thinking value)? thinking,
    TResult? Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult? Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult? Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult? Function(OrchestrateEvent_Complete value)? complete,
    TResult? Function(OrchestrateEvent_Error value)? error,
  }) {
    return complete?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OrchestrateEvent_Thinking value)? thinking,
    TResult Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult Function(OrchestrateEvent_Complete value)? complete,
    TResult Function(OrchestrateEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (complete != null) {
      return complete(this);
    }
    return orElse();
  }
}

abstract class OrchestrateEvent_Complete extends OrchestrateEvent {
  const factory OrchestrateEvent_Complete(
          {required final AgentResponse response}) =
      _$OrchestrateEvent_CompleteImpl;
  const OrchestrateEvent_Complete._() : super._();

  AgentResponse get response;

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrchestrateEvent_CompleteImplCopyWith<_$OrchestrateEvent_CompleteImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$OrchestrateEvent_ErrorImplCopyWith<$Res> {
  factory _$$OrchestrateEvent_ErrorImplCopyWith(
          _$OrchestrateEvent_ErrorImpl value,
          $Res Function(_$OrchestrateEvent_ErrorImpl) then) =
      __$$OrchestrateEvent_ErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$OrchestrateEvent_ErrorImplCopyWithImpl<$Res>
    extends _$OrchestrateEventCopyWithImpl<$Res, _$OrchestrateEvent_ErrorImpl>
    implements _$$OrchestrateEvent_ErrorImplCopyWith<$Res> {
  __$$OrchestrateEvent_ErrorImplCopyWithImpl(
      _$OrchestrateEvent_ErrorImpl _value,
      $Res Function(_$OrchestrateEvent_ErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$OrchestrateEvent_ErrorImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$OrchestrateEvent_ErrorImpl extends OrchestrateEvent_Error {
  const _$OrchestrateEvent_ErrorImpl({required this.message}) : super._();

  @override
  final String message;

  @override
  String toString() {
    return 'OrchestrateEvent.error(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrchestrateEvent_ErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrchestrateEvent_ErrorImplCopyWith<_$OrchestrateEvent_ErrorImpl>
      get copyWith => __$$OrchestrateEvent_ErrorImplCopyWithImpl<
          _$OrchestrateEvent_ErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String text) thinking,
    required TResult Function(String delta) editDelta,
    required TResult Function(List<FileReference> files, String message)
        contextWindowUpdate,
    required TResult Function(AgentContextBudget budget) contextBudgetUpdate,
    required TResult Function(AgentResponse response) complete,
    required TResult Function(String message) error,
  }) {
    return error(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String text)? thinking,
    TResult? Function(String delta)? editDelta,
    TResult? Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult? Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult? Function(AgentResponse response)? complete,
    TResult? Function(String message)? error,
  }) {
    return error?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String text)? thinking,
    TResult Function(String delta)? editDelta,
    TResult Function(List<FileReference> files, String message)?
        contextWindowUpdate,
    TResult Function(AgentContextBudget budget)? contextBudgetUpdate,
    TResult Function(AgentResponse response)? complete,
    TResult Function(String message)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(OrchestrateEvent_Thinking value) thinking,
    required TResult Function(OrchestrateEvent_EditDelta value) editDelta,
    required TResult Function(OrchestrateEvent_ContextWindowUpdate value)
        contextWindowUpdate,
    required TResult Function(OrchestrateEvent_ContextBudgetUpdate value)
        contextBudgetUpdate,
    required TResult Function(OrchestrateEvent_Complete value) complete,
    required TResult Function(OrchestrateEvent_Error value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(OrchestrateEvent_Thinking value)? thinking,
    TResult? Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult? Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult? Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult? Function(OrchestrateEvent_Complete value)? complete,
    TResult? Function(OrchestrateEvent_Error value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(OrchestrateEvent_Thinking value)? thinking,
    TResult Function(OrchestrateEvent_EditDelta value)? editDelta,
    TResult Function(OrchestrateEvent_ContextWindowUpdate value)?
        contextWindowUpdate,
    TResult Function(OrchestrateEvent_ContextBudgetUpdate value)?
        contextBudgetUpdate,
    TResult Function(OrchestrateEvent_Complete value)? complete,
    TResult Function(OrchestrateEvent_Error value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class OrchestrateEvent_Error extends OrchestrateEvent {
  const factory OrchestrateEvent_Error({required final String message}) =
      _$OrchestrateEvent_ErrorImpl;
  const OrchestrateEvent_Error._() : super._();

  String get message;

  /// Create a copy of OrchestrateEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrchestrateEvent_ErrorImplCopyWith<_$OrchestrateEvent_ErrorImpl>
      get copyWith => throw _privateConstructorUsedError;
}
