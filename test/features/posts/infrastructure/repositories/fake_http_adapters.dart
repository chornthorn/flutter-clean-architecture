import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

// Transport doubles for the repositories in this folder: a response to hand
// back, and the request that asked for it.

/// Answers every request with what [respond] builds, recording the method, path
/// and body it was asked for, so a test can pin what the endpoint declares.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<String> requestedPaths = [];
  final List<String> requestedMethods = [];
  final List<dynamic> requestedBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    requestedMethods.add(options.method);
    if (options.data != null) requestedBodies.add(options.data);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Never answers, so the request stays in flight and the cancel future it was
/// handed is the test's to complete.
class PendingAdapter implements HttpClientAdapter {
  Future<void>? cancelFuture;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    this.cancelFuture = cancelFuture;
    return Completer<ResponseBody>().future;
  }

  @override
  void close({bool force = false}) {}
}

/// A JSON response body, the shape the catalog and these tests both speak.
ResponseBody jsonBody(Object? body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
