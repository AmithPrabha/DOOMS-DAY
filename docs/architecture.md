# App flow

Dooms Day App is an offline reference application. Its five destinations are Emergency,
Library, Map, Downloads, and Settings. Nearby messaging is phase two.

## Startup

Entrypoint → initialize Flutter → persistent application support directory →
open Drift database → migrate schema → load essential articles and language strings →
load preferences → override Riverpod providers → display the application.

Production uses [main.dart](../lib/main.dart). Development uses
[main_development.dart](../lib/main_development.dart). The production import graph
never imports `lib/development`. The development application has a different
native application identifier and storage directory.

## Reading and searching

User query → LibraryScreen → AppDatabase.articles → SQLite FTS5 and bounded title
matching → ArticleTile → ArticleScreen. Medicine aliases are indexed with article
text. Search never calls a server. Search queries are parameterized and FTS tokens
are quoted. A missing translation can be opened explicitly in English.

Bookmark → AppDatabase.toggleBookmark → independent bookmark table → revision
provider invalidation → updated bookmark icon. Removing a pack removes its articles
and search records, but not bookmarks.

## Installing a pack

User requests catalog refresh → HTTPS catalog → select pack → check Wi-Fi preference,
budget and free space → download to `.part` → verify length and SHA-256 → inspect
ZIP paths and content → immutable version directory → database transaction activates
articles and installed-pack record.

Failure before activation keeps the previous pack active. Cancellation retains the
partial file. Previous version directories are retained for recovery and count
toward storage. No automatic content expiry makes an installed emergency handbook
unreadable.

## Navigation

Open Map → verify local pack files → rewrite style to local archive and assets →
MapLibre renderer. Tap Locate → request foreground permission → get one GPS fix →
show coordinates and accuracy. Compass subscriptions run only while the map screen
is mounted and the app is in the foreground.

Saved places are independent database records. Distance is great-circle distance;
destination bearing is relative to true north, while the sensor displays magnetic
heading. There is no automatic route calculation or live facility status.

## Module boundaries

Screens call repositories and services through providers. Database code does not
import screens. Pack installation does not mutate preferences or bookmarks.
Device-specific storage operations use the `org.fieldkit/storage` method channel.

Future nearby communication belongs in a separate service with consent, peer
verification, delivery acknowledgements, and real Android/iPhone compatibility
tests. It is not implemented in this release.
