import 'package:firebase_functions/firebase_functions.dart';

/// Comprehensive example testing ALL HTTP function options.
/// This validates that the builder correctly extracts and exports all 21 options.
void main(List<String> args) {
  fireUp(args, (firebase) {
    // Test 1: HTTPS onRequest with ALL GlobalOptions + cors
    firebase.https.onRequest(
      name: 'httpsFull',
      options: const HttpsOptions(
        // GlobalOptions (13 manifest options)
        memory: Memory(MemoryOption.mb512),
        cpu: Cpu(1),
        region: Region(SupportedRegion.usCentral1),
        timeoutSeconds: TimeoutSeconds(60),
        minInstances: Instances(0),
        maxInstances: Instances(10),
        concurrency: Concurrency(80),
        serviceAccount: ServiceAccount('test@example.com'),
        vpcConnector: VpcConnector(
          'projects/test/locations/us-central1/connectors/vpc',
        ),
        vpcConnectorEgressSettings: VpcConnectorEgressSettings(
          VpcEgressSetting.privateRangesOnly,
        ),
        ingressSettings: Ingress(IngressSetting.allowAll),
        invoker: Invoker.public(),
        labels: {
          'environment': 'test',
          'team': 'backend',
        },
        omit: Omit(false),
        // Runtime-only options (NOT in manifest)
        preserveExternalChanges: PreserveExternalChanges(true),
        cors: Cors(['https://example.com', 'https://app.example.com']),
      ),
      (request) async => Response.ok('HTTPS with all options'),
    );

    // Test 2: Callable with ALL CallableOptions
    firebase.https.onCall(
      name: 'callableFull',
      options: const CallableOptions(
        memory: Memory(MemoryOption.gb1),
        cpu: Cpu(2),
        region: Region(SupportedRegion.usEast1),
        timeoutSeconds: TimeoutSeconds(300),
        minInstances: Instances(1),
        maxInstances: Instances(100),
        concurrency: Concurrency(80),
        invoker: Invoker.private(),
        labels: {
          'type': 'callable',
        },
        // Runtime-only options (NOT in manifest)
        enforceAppCheck: EnforceAppCheck(true),
        consumeAppCheckToken: ConsumeAppCheckToken(true),
        heartBeatIntervalSeconds: HeartBeatIntervalSeconds(30),
        cors: Cors(['*']),
      ),
      (request, response) async {
        return CallableResult({'message': 'Callable with all options'});
      },
    );

    // Test 3: GCF Gen1 CPU option
    firebase.https.onRequest(
      name: 'httpsGen1',
      options: const HttpsOptions(
        cpu: Cpu.gcfGen1(),
      ),
      (request) async => Response.ok('GCF Gen1 CPU'),
    );

    // Test 4: Custom invoker list
    firebase.https.onRequest(
      name: 'httpsCustomInvoker',
      options: const HttpsOptions(
        invoker: Invoker(['user1@example.com', 'user2@example.com']),
      ),
      (request) async => Response.ok('Custom invoker'),
    );

    // Test 5: Pub/Sub with options
    firebase.pubsub.onMessagePublished(
      topic: 'options-topic',
      options: const PubSubOptions(
        memory: Memory(MemoryOption.mb256),
        timeoutSeconds: TimeoutSeconds(120),
        region: Region(SupportedRegion.usWest1),
      ),
      (event) async {
        print('Pub/Sub with options');
      },
    );

    print('All functions with options registered!');
  });
}
