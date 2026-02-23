import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Basic scheduled function - runs every day at midnight
    firebase.scheduler.onSchedule(schedule: '0 0 * * *', (event) async {
      print('Scheduled function triggered:');
      print('  Job Name: ${event.jobName}');
      print('  Schedule Time: ${event.scheduleTime}');
    });

    // Scheduled function with timezone and retry config
    firebase.scheduler.onSchedule(
      schedule: '0 9 * * 1-5',
      options: const ScheduleOptions(
        timeZone: TimeZone('America/New_York'),
        retryConfig: RetryConfig(
          retryCount: RetryCount(3),
          maxRetrySeconds: MaxRetrySeconds(60),
          minBackoffSeconds: MinBackoffSeconds(5),
          maxBackoffSeconds: MaxBackoffSeconds(30),
        ),
        memory: Memory(MemoryOption.mb256),
      ),
      (event) async {
        print('Weekday morning report:');
        print('  Executed at: ${event.scheduleDateTime}');
      },
    );
  });
}
