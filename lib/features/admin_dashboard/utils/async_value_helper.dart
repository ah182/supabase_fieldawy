import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncValueHelper<T> on AsyncValue<T> {
  R safeWhen<R>({
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function(T data) data,
  }) {
    if (isLoading && !hasValue) {
      return loading();
    }
    
    if (hasError && !hasValue) {
      return error(this.error!, stackTrace!);
    }
    
    if (hasValue) {
      return data(value!);
    }
    
    // Fallback
    return loading();
  }
}