// Copyright (c) 2021, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http/http.dart' as dart_http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_static/shelf_static.dart' as shelf_static;

Future main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  // See https://pub.dev/documentation/shelf/latest/shelf/Cascade-class.html
  final cascade = Cascade().add(_staticHandler).add(_router);

  // See https://pub.dev/documentation/shelf/latest/shelf_io/serve.html
  final server = await shelf_io.serve(
    logRequests().addHandler(cascade.handler),
    InternetAddress.anyIPv4, // Allows external connections
    port,
  );

  print('Serving at http://${server.address.host}:${server.port}');
}

final client = dart_http.Client();

// Serve files from the file system.
final _router = shelf_router.Router()
  ..get('/maps/api/place/autocomplete/json', _placesHandler)
  ..get('/maps/api/place/details/json', _detailsHander)
  ..get(
    '/time',
    (request) => Response.ok(DateTime.now().toUtc().toIso8601String()),
  );

// Router instance to handler requests.
final _staticHandler =
    shelf_static.createStaticHandler('public', defaultDocument: 'index.html');

Future<Response> _detailsHander(Request request) async {
  Map<String, String> params = request.requestedUri.queryParameters;

  final response = await client.get(
    Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': params['place_id'],
      'key': params['key'],
      'sessiontoken': params['sessiontoken']
    }),
  );

  return Response.ok(response.body, headers: {
    'content-type': 'application/json',
    'Cache-Control': 'public, max-age=604800',
    // the whole reason this proxy exists, to add the access-control header
    'Access-Control-Allow-Origin': '*'
  });
}

// Can probably make a generic proxy but YOLO for now.
Future<Response> _placesHandler(Request request) async {
  Map<String, String> params = request.requestedUri.queryParameters;

  final response = await client.get(
    Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': params['input'],
      'types': params['types'],
      'key': params['key'],
      'sessiontoken': params['sessiontoken']
    }),
  );

  return Response.ok(response.body, headers: {
    'content-type': 'application/json',
    'Cache-Control': 'public, max-age=604800',
    // the whole reason this proxy exists, to add the access-control header
    'Access-Control-Allow-Origin': '*'
  });
}
