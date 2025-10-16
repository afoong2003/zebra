
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart'; 

Future<void> main() async {
  
  final dotEnv = DotEnv(includePlatformEnvironment: true)..load();

  
  final connection = PostgreSQLConnection(
    dotEnv['DB_HOST'] ?? 'localhost', 
    int.parse(dotEnv['DB_PORT'] ?? '5432'),
    dotEnv['DB_NAME'] ?? 'mydatabase',
    username: dotEnv['DB_USER'] ?? 'user',
    password: dotEnv['DB_PASSWORD'] ?? 'password',
  );

  await connection.open();
  print('Connected to PostgreSQL!');

  final app = Router();

  app.get('/', (Request request) {
  return Response.ok('API server is running.');
});

  final server = await io.serve(app, 'localhost', 8080);
  print('Server listening on port ${server.port}');
}