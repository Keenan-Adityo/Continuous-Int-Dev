import '../../domain/entities/savings_goal.dart';

abstract final class SavingsGoalModel {
  static Map<String, dynamic> encode(SavingsGoal goal) => {
    'id': goal.id,
    'title': goal.title,
    'targetAmount': goal.targetAmount,
    'targetDate': goal.targetDate?.toIso8601String(),
    'contributions': goal.contributions
        .map(
          (c) => {
            'id': c.id,
            'amount': c.amount,
            'date': c.date.toIso8601String(),
          },
        )
        .toList(),
  };

  static SavingsGoal decode(Map<String, dynamic> json) {
    final goal = SavingsGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      targetAmount: json['targetAmount'] as int,
      targetDate: json['targetDate'] == null
          ? null
          : DateTime.parse(json['targetDate'] as String),
      contributions: (json['contributions'] as List).map((value) {
        final item = value as Map<String, dynamic>;
        return GoalContribution(
          id: item['id'] as String,
          amount: item['amount'] as int,
          date: DateTime.parse(item['date'] as String),
        );
      }).toList(),
    );
    goal.validate();
    return goal;
  }
}
