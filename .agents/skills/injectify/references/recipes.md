# Common Injectify Recipes & Patterns

Practical real-world patterns for Dart & Flutter applications.

---

## 1. Third-Party Dependencies (`@ExternalModule`)

When registering classes from third-party packages that cannot be annotated directly (e.g. `Dio`, `SharedPreferences`, `FlutterSecureStorage`, `FirebaseFirestore`).

```dart
import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';
import 'package:shared_preferences/shared_preferences.dart';

@ExternalModule()
abstract class CoreExternalModule {
  // Synchronous Lazy Singleton
  @Injectable(scope: Scope.lazySingleton)
  Dio dio() {
    return Dio(BaseOptions(
      baseUrl: 'https://api.example.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  // Asynchronous Eager Singleton with @PreResolve
  @PreResolve()
  @Injectable(scope: Scope.singleton)
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

---

## 2. BLoC / Cubit State Management

In Flutter apps using `flutter_bloc`, BLoCs and Cubits should typically be registered as `Scope.factory` (or scoped to pages/widgets).

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectify/injectify.dart';

abstract class AuthState {}
class AuthInitial extends AuthState {}

@Injectable(scope: Scope.factory)
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(AuthInitial());

  Future<void> login(String email, String password) async {
    // login logic
  }
}
```

### In Flutter Widget Tree

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AuthCubit>(),
      child: const LoginForm(),
    );
  }
}
```

---

## 3. Dynamic Factory Parameters (`@FactoryParam`)

Passing runtime arguments dynamically when looking up a dependency.

```dart
@Injectable(scope: Scope.factory)
class OrderDetailBloc extends Cubit<OrderDetailState> {
  final OrderRepository repository;
  final String orderId;

  OrderDetailBloc(
    this.repository, {
    @FactoryParam() required this.orderId,
  }) : super(OrderDetailInitial());
}
```

### Looking Up with Params

```dart
// Look up by passing param1:
final bloc = getIt<OrderDetailBloc>(param1: 'order_9876');
```

---

## 4. Multi-Environment Switching & Mocking

Configuring dev, prod, and test implementations.

```dart
abstract class PaymentGateway {
  Future<bool> charge(double amount);
}

// Dev & Test environment mock
@Environment(Environment.dev)
@Environment(Environment.test)
@Injectable(as: PaymentGateway, scope: Scope.lazySingleton)
class MockPaymentGateway implements PaymentGateway {
  @override
  Future<bool> charge(double amount) async => true;
}

// Production real gateway
@Environment(Environment.prod)
@Injectable(as: PaymentGateway, scope: Scope.lazySingleton)
class StripePaymentGateway implements PaymentGateway {
  final Dio dio;
  StripePaymentGateway(this.dio);

  @override
  Future<bool> charge(double amount) async {
    // real payment call
    return true;
  }
}
```

### Testing Setup in `test/`

```dart
void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
  });

  test('charge returns true in test env', () async {
    final gateway = getIt<PaymentGateway>();
    expect(await gateway.charge(100.0), isTrue);
  });
}
```

---

## 5. Multiple Instances with Named Tags (`@Inject`)

When you need multiple instances of the same class configured differently.

```dart
@ExternalModule()
abstract class NetworkClientsModule {
  @Injectable(scope: Scope.lazySingleton)
  @Inject('publicApi')
  Dio publicDio() => Dio(BaseOptions(baseUrl: 'https://public.api.com'));

  @Injectable(scope: Scope.lazySingleton)
  @Inject('privateApi')
  Dio privateDio(AuthInterceptor interceptor) {
    final dio = Dio(BaseOptions(baseUrl: 'https://private.api.com'));
    dio.interceptors.add(interceptor);
    return dio;
  }
}

@Injectable(scope: Scope.factory)
class PublicCatalogService {
  final Dio dio;
  PublicCatalogService(@Inject('publicApi') this.dio);
}

@Injectable(scope: Scope.factory)
class UserAccountService {
  final Dio dio;
  UserAccountService(@Inject('privateApi') this.dio);
}
```
