import '../../errors/api/api_error.dart';
import '../result.dart';

/// The [Result] an [ApiManager] call returns: a value or an [ApiError].
///
/// It is an alias rather than a subclass because [Result] is sealed — which is
/// what makes `switch` over a result exhaustive. Construction reads the same
/// as before: `ApiResult.success(value: x)` / `ApiResult.failure(error)`, and
/// so does matching: `case Success(:final value)`.
typedef ApiResult<TValue extends Object> = Result<TValue, ApiError>;
