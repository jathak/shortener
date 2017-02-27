A very simple URL shortener.

    pub get
    dart bin/server.dart prep  # copy the auth token that is output
    dart bin/server.dart <port>

Go to `/_auth-<auth token>` and it should redirect you to `/_manage`, where you
can add or delete short links. Change `[base]` to configure where an empty path
redirects to. Short links can be anything, provided they don't start with an
underscore.

All short links (plus the auth token) are stored in `data.json`. Delete this if
you want to clear all short links. Rerun the prep command to change the auth
token. The short links will be left untouched.
