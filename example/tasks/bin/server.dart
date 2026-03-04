import 'package:firebase_functions/firebase_functions.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Basic task queue function
    firebase.tasks.onTaskDispatched(name: 'processOrder', (request) async {
      final data = request.data as Map<String, dynamic>;
      print('Processing order: ${data['orderId']}');
      print('Task ID: ${request.id}');
      print('Queue: ${request.queueName}');
      print('Retry count: ${request.retryCount}');
    });

    // Task queue function with options
    firebase.tasks.onTaskDispatched(
      name: 'sendEmail',
      options: const TaskQueueOptions(
        retryConfig: TaskQueueRetryConfig(
          maxAttempts: MaxAttempts(5),
          maxRetrySeconds: TaskMaxRetrySeconds(300),
          minBackoffSeconds: TaskMinBackoffSeconds(10),
          maxBackoffSeconds: TaskMaxBackoffSeconds(60),
          maxDoublings: TaskMaxDoublings(3),
        ),
        rateLimits: TaskQueueRateLimits(
          maxConcurrentDispatches: MaxConcurrentDispatches(100),
          maxDispatchesPerSecond: MaxDispatchesPerSecond(50),
        ),
        memory: Memory(MemoryOption.mb512),
      ),
      (request) async {
        final data = request.data as Map<String, dynamic>;
        print('Sending email to: ${data['to']}');
        print('Subject: ${data['subject']}');
      },
    );
  });
}
