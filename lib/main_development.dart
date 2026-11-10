import 'bootstrap.dart';
import 'development/test_center.dart';

void main() =>
    bootstrap(development: true, developerTools: (_) => const TestCenter());
