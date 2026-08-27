<?php

declare(strict_types=1);

/**
 * TEST-ONLY fixture page for the Arabic source pipeline.
 * ------------------------------------------------------
 * Routed through the front controller as `GET /api/test/source-page/{episodeId}`
 * (and `/api/test/source-page`). It returns a small, static HTML "watch page"
 * containing known-good, license-free public test streams so you can prove the
 * ScraperService end to end: fetch → DOM/regex parse → extract → normalize →
 * play — without pointing the scraper at anyone's real site.
 *
 * How to use:
 *   1. In backend/.env set:
 *        ENABLE_TEST_SOURCE_PAGE=true
 *        ARABIC_SOURCE_BASE_URL=https://<your-host>/api/test/source-page
 *   2. Open any episode in the app with language = Arabic, or curl:
 *        GET /api/episodes/sources?episode_id=demo_1&lang=ar
 *      You should get a `sources` array whose first entry is a playable MP4.
 *
 * Safety: disabled unless ENABLE_TEST_SOURCE_PAGE=true, so it can never be left
 * serving in production by accident. bootstrap.php has already run (the router
 * includes this file), so env() and Response are available.
 */

if (env('ENABLE_TEST_SOURCE_PAGE') !== 'true') {
    // Behaves like any other unknown endpoint when the fixture is off.
    Response::error('Not found.', 404);
}

// The scraper fetches this exactly like a real watch page and parses the HTML,
// so override the JSON content-type bootstrap set and emit real HTML.
header('Content-Type: text/html; charset=utf-8');

// The episode id the scraper appended arrives as the {episodeId} route param.
// We only echo it back into a comment so you can see the request reached here;
// every id resolves to the same known-good fixture, which is all the pipeline
// test needs.
$episodeId = htmlspecialchars(
    (string) ($_GET['episodeId'] ?? ''),
    ENT_QUOTES,
    'UTF-8'
);

// Public, license-free test assets:
//  - Big Buck Bunny (Blender Foundation, CC-BY) — progressive MP4.
//  - Mux public HLS test stream — adaptive .m3u8.
echo <<<HTML
<!doctype html>
<html lang="ar">
<head>
  <meta charset="utf-8">
  <title>AnimeWatcher — source pipeline test fixture</title>
</head>
<body>
  <!-- episode requested: {$episodeId} -->

  <!--
    NOTE: A real embed player would appear as an <iframe> here. It is left
    commented out on purpose: the app plays direct MP4/HLS, not arbitrary
    embeds, so keeping the first extracted source a playable file lets this
    fixture verify actual playback. Uncomment to exercise iframe extraction:
    <iframe src="https://example.com/embed/demo"></iframe>
  -->

  <!-- Direct progressive MP4 via <video>/<source> — extracted first, so the
       player receives a playable link as sources[0]. -->
  <video controls>
    <source
      src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
      type="video/mp4"
      label="720p">
  </video>

  <!-- Player configured from inline JS, the common real-world case. The URLs
       use JSON slash-escaping ("https:\/\/…") so this also exercises the
       unescape + .m3u8/.mp4 regex extraction path. -->
  <script>
    var player = setup({
      "sources": [
        {"file": "https:\/\/test-streams.mux.dev\/x36xhzz\/x36xhzz.m3u8", "label": "auto"},
        {"file": "https:\/\/commondatastorage.googleapis.com\/gtv-videos-bucket\/sample\/ForBiggerBlazes.mp4", "label": "1080p"}
      ]
    });
  </script>
</body>
</html>
HTML;
