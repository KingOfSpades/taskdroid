// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DateUpdate {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DateUpdate);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DateUpdate()';
}


}

/// @nodoc
class $DateUpdateCopyWith<$Res>  {
$DateUpdateCopyWith(DateUpdate _, $Res Function(DateUpdate) __);
}


/// Adds pattern-matching-related methods to [DateUpdate].
extension DateUpdatePatterns on DateUpdate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( DateUpdate_Keep value)?  keep,TResult Function( DateUpdate_Remove value)?  remove,TResult Function( DateUpdate_Set value)?  set_,required TResult orElse(),}){
final _that = this;
switch (_that) {
case DateUpdate_Keep() when keep != null:
return keep(_that);case DateUpdate_Remove() when remove != null:
return remove(_that);case DateUpdate_Set() when set_ != null:
return set_(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( DateUpdate_Keep value)  keep,required TResult Function( DateUpdate_Remove value)  remove,required TResult Function( DateUpdate_Set value)  set_,}){
final _that = this;
switch (_that) {
case DateUpdate_Keep():
return keep(_that);case DateUpdate_Remove():
return remove(_that);case DateUpdate_Set():
return set_(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( DateUpdate_Keep value)?  keep,TResult? Function( DateUpdate_Remove value)?  remove,TResult? Function( DateUpdate_Set value)?  set_,}){
final _that = this;
switch (_that) {
case DateUpdate_Keep() when keep != null:
return keep(_that);case DateUpdate_Remove() when remove != null:
return remove(_that);case DateUpdate_Set() when set_ != null:
return set_(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  keep,TResult Function()?  remove,TResult Function( String field0)?  set_,required TResult orElse(),}) {final _that = this;
switch (_that) {
case DateUpdate_Keep() when keep != null:
return keep();case DateUpdate_Remove() when remove != null:
return remove();case DateUpdate_Set() when set_ != null:
return set_(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  keep,required TResult Function()  remove,required TResult Function( String field0)  set_,}) {final _that = this;
switch (_that) {
case DateUpdate_Keep():
return keep();case DateUpdate_Remove():
return remove();case DateUpdate_Set():
return set_(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  keep,TResult? Function()?  remove,TResult? Function( String field0)?  set_,}) {final _that = this;
switch (_that) {
case DateUpdate_Keep() when keep != null:
return keep();case DateUpdate_Remove() when remove != null:
return remove();case DateUpdate_Set() when set_ != null:
return set_(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class DateUpdate_Keep extends DateUpdate {
  const DateUpdate_Keep(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DateUpdate_Keep);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DateUpdate.keep()';
}


}




/// @nodoc


class DateUpdate_Remove extends DateUpdate {
  const DateUpdate_Remove(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DateUpdate_Remove);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DateUpdate.remove()';
}


}




/// @nodoc


class DateUpdate_Set extends DateUpdate {
  const DateUpdate_Set(this.field0): super._();
  

 final  String field0;

/// Create a copy of DateUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DateUpdate_SetCopyWith<DateUpdate_Set> get copyWith => _$DateUpdate_SetCopyWithImpl<DateUpdate_Set>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DateUpdate_Set&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'DateUpdate.set_(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $DateUpdate_SetCopyWith<$Res> implements $DateUpdateCopyWith<$Res> {
  factory $DateUpdate_SetCopyWith(DateUpdate_Set value, $Res Function(DateUpdate_Set) _then) = _$DateUpdate_SetCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$DateUpdate_SetCopyWithImpl<$Res>
    implements $DateUpdate_SetCopyWith<$Res> {
  _$DateUpdate_SetCopyWithImpl(this._self, this._then);

  final DateUpdate_Set _self;
  final $Res Function(DateUpdate_Set) _then;

/// Create a copy of DateUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(DateUpdate_Set(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
