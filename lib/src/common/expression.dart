/// Abstract base class for all expressions in Firebase Functions.
///
/// Expressions allow configuration values to be determined at deploy time
/// using CEL (Common Expression Language) or at runtime using environment
/// variables and parameters.
abstract class Expression<T extends Object> {
  /// Gets the runtime value of this expression.
  ///
  /// For parameters, this reads from environment variables.
  /// For literals, this returns the literal value.
  T value() => runtimeValue();

  /// Evaluates this expression to get its runtime value.
  T runtimeValue();

  /// Converts this expression to CEL (Common Expression Language) format.
  ///
  /// CEL expressions are used in deployment manifests to express conditional
  /// logic and parameter references.
  String toCEL() => '{{ ${toString()} }}';

  /// Converts this expression to JSON for serialization.
  String toJSON() => toString();

  /// Helper method to convert any value to CEL format.
  static String valueToCEL(Object value) => '{{ ${value.toString()} }}';

  const Expression();

  /// Creates a conditional expression (ternary operator).
  ///
  /// Example:
  /// ```dart
  /// final region = isProduction.when(
  ///   then: Expression(['us-central1', 'europe-west1']),
  ///   otherwise: Expression(['us-central1']),
  /// );
  /// ```
  If<T> when({
    required Expression<T> then,
    required Expression<T> otherwise,
  }) {
    if (this is! ComparableExpression<Object>) {
      throw ArgumentError(
        'when() can only be called on ComparableExpression',
      );
    }
    return If(
      this as ComparableExpression<Object>,
      then: then,
      otherwise: otherwise,
    );
  }

  /// Creates an equality comparison expression.
  Equals<T> equals(Expression<T> other) => Equals(this, other);

  /// Creates an inequality comparison expression.
  NotEquals<T> notEquals(Expression<T> other) => NotEquals(this, other);
}

/// A conditional expression (ternary operator).
///
/// Evaluates [test] and returns [then] if true, [otherwise] if false.
final class If<T extends Object> extends Expression<T> {
  final ComparableExpression<Object> test;
  final Expression<T> then;
  final Expression<T> otherwise;

  const If(this.test, {required this.then, required this.otherwise});

  @override
  T runtimeValue() =>
      test.runtimeValue() ? then.runtimeValue() : otherwise.runtimeValue();

  @override
  String toString() =>
      '${test.toString()} ? ${then.toString()} : ${otherwise.toString()}';
}

/// Base class for comparison expressions that return boolean values.
sealed class ComparableExpression<T extends Object> extends Expression<bool> {
  final Expression<T> lhs;
  final Expression<T> rhs;

  const ComparableExpression(this.lhs, this.rhs);

  /// Helper method to compare two lists for equality.
  bool _arrayEquals(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    return left.every(right.contains) && right.every(left.contains);
  }
}

/// Equality comparison expression.
final class Equals<T extends Object> extends ComparableExpression<T> {
  const Equals(super.lhs, super.rhs);

  @override
  bool runtimeValue() {
    final left = lhs.runtimeValue();
    final right = rhs.runtimeValue();

    if (left is List && right is List) {
      return _arrayEquals(left as List<T>, right as List<T>);
    }

    return left == right;
  }

  @override
  String toString() => '${lhs.toString()} == ${rhs.toString()}';
}

/// Inequality comparison expression.
final class NotEquals<T extends Object> extends ComparableExpression<T> {
  const NotEquals(super.lhs, super.rhs);

  @override
  bool runtimeValue() {
    final left = lhs.runtimeValue();
    final right = rhs.runtimeValue();

    if (left is List && right is List) {
      return !_arrayEquals(left as List<T>, right as List<T>);
    }

    return left != right;
  }

  @override
  String toString() => '${lhs.toString()} != ${rhs.toString()}';
}

/// Greater than comparison expression (numbers only).
final class GreaterThan extends ComparableExpression<num> {
  const GreaterThan(super.lhs, super.rhs);

  @override
  bool runtimeValue() => lhs.runtimeValue() > rhs.runtimeValue();

  @override
  String toString() => '${lhs.toString()} > ${rhs.toString()}';
}

/// Greater than or equal comparison expression (numbers only).
final class GreaterThanOrEqualTo extends ComparableExpression<num> {
  const GreaterThanOrEqualTo(super.lhs, super.rhs);

  @override
  bool runtimeValue() => lhs.runtimeValue() >= rhs.runtimeValue();

  @override
  String toString() => '${lhs.toString()} >= ${rhs.toString()}';
}

/// Less than comparison expression (numbers only).
final class LessThan extends ComparableExpression<num> {
  const LessThan(super.lhs, super.rhs);

  @override
  bool runtimeValue() => lhs.runtimeValue() < rhs.runtimeValue();

  @override
  String toString() => '${lhs.toString()} < ${rhs.toString()}';
}

/// Less than or equal comparison expression (numbers only).
final class LessThanOrEqualTo extends ComparableExpression<num> {
  const LessThanOrEqualTo(super.lhs, super.rhs);

  @override
  bool runtimeValue() => lhs.runtimeValue() <= rhs.runtimeValue();

  @override
  String toString() => '${lhs.toString()} <= ${rhs.toString()}';
}

/// A literal expression that wraps a constant value.
final class LiteralExpression<T extends Object> extends Expression<T> {
  final T literal;

  const LiteralExpression(this.literal);

  @override
  T runtimeValue() => literal;

  @override
  String toString() {
    if (literal is String) {
      return '"$literal"';
    }
    if (literal is List) {
      return '[${(literal as List).map((e) => e.toString()).join(', ')}]';
    }
    return literal.toString();
  }
}
