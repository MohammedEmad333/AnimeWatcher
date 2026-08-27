import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';

/// Singleton [DioClient] shared by every remote datasource.
final dioClientProvider = Provider<DioClient>((ref) => DioClient());
