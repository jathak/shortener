import 'dart:io';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:math' show Random;
import 'dart:convert' show JSON;

main(args) {
  if (args.first == 'prep') {
    return prep();
  }
  int port = int.parse(args.first);
  runZoned(() => server(port), onError: (e, stackTrace) {
    print('Error: $e $stackTrace');
    main(args);
  });
}

server(port) async {
  var server = await HttpServer.bind('0.0.0.0', port);
  var datapath = Platform.script.resolve('../data.json').toFilePath();
  Map<String, String> redirects = JSON.decode(await new File(datapath).readAsString());
  String authcode = redirects['_authcode'];
  await for (var request in server) {
    String path = request.uri.path;
    if (path == '/' && redirects.containsKey('[base]')) {
      request.response.redirect(Uri.parse(redirects['[base]']));
    }
    if (path.startsWith('/_auth-')) {
      String testcode = path.split('-').last;
      if (authcode == testcode) {
        var cookie = new Cookie('authcode', authcode);
        cookie.expires = new DateTime.now().add(new Duration(days: 365));
        cookie.httpOnly = false;
        request.response.cookies.add(cookie);
        request.response.redirect(Uri.parse('/_manage'));
      } else {
        failAuth(request);
      }
      continue;
    }
    if (path.startsWith('/_manage')) {
      var cookie = request.cookies.firstWhere((c)=>c.name=='authcode');
      if (authcode != cookie?.value) {
        failAuth(request);
      }
      if (path.startsWith('/_manage/register/')) {
        var parts = path.substring('/_manage/register/'.length).split('/');
        String short = Uri.decodeComponent(parts[0]);
        String url = Uri.decodeComponent(parts[1]);
        if (!short.startsWith('_')) {
          redirects[short] = url;
          saveRedirects(redirects);
          request.response.redirect(Uri.parse('/_manage'));
        } else failAuth(request);
      } else if (path.startsWith('/_manage/delete/')) {
        String short = Uri.decodeComponent(path.split('/').last);
        if (!short.startsWith('_')) {
          redirects.remove(short);
          saveRedirects(redirects);
          request.response.redirect(Uri.parse('/_manage'));
        } else failAuth(request);
      } else {
        request.response.headers.set('content-type', 'text/html; charset=utf-8');
        request.response.write(makeManage(redirects, path));
        request.response.close();
      }
      continue;
    }
    String key = path.substring(1);
    if (!key.startsWith('_') && redirects.containsKey(key)) {
      request.response.redirect(Uri.parse(redirects[key]));
    }
    request.response.write('Invalid request');
    request.response.close();
  }
}

String makeManage(Map<String, String> redirects, String path) {
  return """
    <!DOCTYPE html>
    <html><head><title>Short Link Manager</title>
    <script type='text/javascript'>
      function register() {
        var url = document.getElementById('url').value;
        var short = document.getElementById('short').value;
        short = encodeURIComponent(short);
        url = encodeURIComponent(url);
        document.location.href = document.location.href + '/register/' + short + '/' + url;
      }
    </script>
    </head>
    <body>
    Short Name: <input id='short' width='100'/><br>
    URL: <input id='url' width='300'/><br>
    <button onclick="register()">Register</button><br><br><br>
    ${redirects.keys.where((k)=>!k.startsWith('_')).map((k) {
      return '$k: ${redirects[k]} (<a href="/_manage/delete/${Uri.encodeComponent(k)}">Delete</a>)';
    }).join('<br>')}
    </body>
    </html>
  """.trim();
}

saveRedirects(redirects) async {
  var datapath = Platform.script.resolve('../data.json').toFilePath();
  var file = new File(datapath);
  await file.writeAsString(JSON.encode(redirects));
}

failAuth(request) => request.response.redirect(Uri.parse('/_invalid'));

prep() async {
  var datapath = Platform.script.resolve('../data.json').toFilePath();
  var file = new File(datapath);
  if (!(await file.exists())) {
    await file.create();
    await file.writeAsString("{}");
  }
  var r = new Random.secure();
  var randomNumbers = new List.generate(8192, (_)=>r.nextInt(256));
  String authcode = (sha256 as Sha256).convert(randomNumbers).toString();
  Map<String, String> data = JSON.decode(await file.readAsString());
  data['_authcode'] = authcode;
  if (!data.containsKey('[base]')) {
    data['[base]'] = 'https://github.com/jathak/shortener';
  }
  await saveRedirects(data);
  print('Authorization Code:\n$authcode');
}
