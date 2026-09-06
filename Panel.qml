import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// Search IMDb's own (unofficial, keyless) suggestion endpoint for movies/TV
// shows and show the top 5 results with poster, title/year, and a
// ready-made Radarr/Sonarr-style folder name. Left click (or Enter, once
// selected) opens a title on IMDb; right click (or Space) copies its
// folder name. ↓/↑ move the selection, reaching past the last result to
// an "open full search on IMDb.com" button; the ? icon toggles an
// in-panel reminder of these shortcuts.
Panel {
  id: root
  moduleName: "andersdosen.imdbsearch"
  ipcTarget: "andersdosen.imdbsearch"

  readonly property string icon: "" // nf-fa-film

  property string query: ""
  property var results: []
  property bool searching: false
  property string errorText: ""
  // Keyboard-selected row, -1 = none (plain typing). Down/Up move it;
  // Enter/Space act on it and are otherwise left alone so they keep
  // working as literal input.
  property int selectedIndex: -1

  // Click-to-reveal shortcuts hint, toggled by the help button.
  property bool showHelp: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  // ---------- folder-name formatting ----------

  // "/" reads as a path separator, not punctuation, so it becomes "-"
  // instead of vanishing outright (e.g. "Face/Off" -> "Face-Off" rather
  // than "FaceOff") before the rest of the illegal-character set (still
  // Windows-illegal, which also covers the shared-drive/NAS case) is
  // stripped, whitespace collapsed, and trailing dots/spaces trimmed.
  function sanitizeTitle(title) {
    return String(title || "")
      .replace(/\//g, "-")
      .replace(/[\\:*?"<>|]/g, "")
      .replace(/\s+/g, " ")
      .replace(/^[\s.]+|[\s.]+$/g, "")
  }

  // IMDb's suggest endpoint already gives a plain start year ("y"); this
  // just defensively pulls 4 digits out of whatever ends up in Year in case
  // that field is ever missing or formatted oddly.
  function startYear(year) {
    var m = String(year || "").match(/\d{4}/)
    return m ? m[0] : ""
  }

  function folderName(item) {
    if (!item) return ""
    var year = root.startYear(item.Year)
    var title = root.sanitizeTitle(item.Title)
    return title + (year ? " (" + year + ")" : "") + " [imdbid-" + item.imdbID + "]"
  }

  function imdbUrl(item) {
    return "https://www.imdb.com/title/" + item.imdbID + "/"
  }

  function openResult(item) {
    if (!item) return
    Util.execArgv(["omarchy-launch-browser", root.imdbUrl(item)])
  }

  function imdbSearchUrl() {
    return "https://www.imdb.com/find/?q=" + encodeURIComponent(root.query.replace(/^\s+|\s+$/g, ""))
  }

  function openMoreResults() {
    Util.execArgv(["omarchy-launch-browser", root.imdbSearchUrl()])
  }

  // Row-scoped "copied" feedback: the just-copied row swaps its folder-name
  // line for an accent-colored confirmation for 2s, then reverts. Tracked
  // by imdbID rather than index since results can change while the timer
  // is running.
  property string copiedImdbId: ""

  function copyFolderName(item) {
    if (!item) return
    Util.execDetached("printf %s " + Util.shellQuote(root.folderName(item)) + " | wl-copy")
    root.copiedImdbId = item.imdbID
    copiedTimer.restart()
  }

  Timer {
    id: copiedTimer
    interval: 2000
    onTriggered: root.copiedImdbId = ""
  }

  // The suggest response is unauthenticated third-party content; before it's
  // ever handed to Image as a source, require it actually points at an IMDb
  // poster CDN host over https (not e.g. file:// or an arbitrary http(s)
  // host a compromised/MITM'd response could substitute) AND already
  // carries the plain "._V1_" size marker. That marker is what thumbUrl()
  // rewrites into a bounded thumbnail suffix below, so requiring it here
  // means a URL that passes this check can always be capped to a small
  // decoded/downloaded size — there's no case where a "trusted host" URL
  // without the marker falls through and hands Image an unbounded,
  // multi-megabyte full-res original.
  function isTrustedPosterUrl(url) {
    return /^https:\/\/([a-z0-9-]+\.)*(media-amazon\.com|media-imdb\.com)\/.*\._V1_\./i.test(String(url || ""))
  }

  // Rewrites the "._V1_" size marker into a fixed small-size suffix.
  // Only ever called after isTrustedPosterUrl() has confirmed the marker
  // is present, so this always succeeds in bounding the image.
  function thumbUrl(url) {
    return String(url || "").replace("._V1_.", "._V1_UX140_.")
  }

  // ---------- poster fetching ----------

  // A same-host, same-marker thumbnail URL is still someone else's
  // response: sourceSize alone bounds decoded pixels, not the bytes an
  // Image.source fetch will read off the wire, and QML's own network
  // fetch has no byte cap, content-type check, or redirect revalidation
  // of its own. Posters are instead pulled through fetch-poster, a
  // helper that enforces all of that, into a small local cache; only the
  // resulting local file ever reaches Image.source.
  readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
  readonly property string posterCacheDir: root.cacheHome + "/omarchy-imdbsearch/posters"
  readonly property string fetchPosterHelper: Qt.resolvedUrl("fetch-poster").toString().replace(/^file:\/\//, "")
  readonly property string fetchSuggestHelper: Qt.resolvedUrl("fetch-suggest").toString().replace(/^file:\/\//, "")

  // root.results is a plain array, so every completed search rebuilds
  // every ResultRow delegate from scratch (Repeater can't diff a plain
  // array the way it can a ListModel) — without this, the same imdbID
  // appearing across searches (typing "bat" -> "batm") would respawn a
  // fetch-poster process each time, even though the previous fetch already
  // proved the file is cached on disk. Keyed by imdbID, persists across
  // rebuilds since it lives on root rather than a row.
  property var posterCacheKnownGood: ({})

  function posterCachePath(imdbID) {
    return root.posterCacheDir + "/" + String(imdbID || "") + ".jpg"
  }

  Process {
    id: posterCacheDirProc
    command: ["mkdir", "-p", root.posterCacheDir]
  }
  Component.onCompleted: posterCacheDirProc.running = true

  // ---------- keyboard selection ----------

  // delta +1/-1. From "none" (plain typing), Down lands on the first
  // result and Up lands on the "Open search results" button (index ===
  // results.length) — the actual first/last stops in the list, in either
  // direction. Down past the button, or Up past the first result, wraps
  // back to "none".
  function moveSelection(delta) {
    if (root.results.length === 0) return
    var buttonIndex = root.results.length
    if (root.selectedIndex < 0) {
      root.selectedIndex = delta > 0 ? 0 : buttonIndex
      return
    }
    var next = root.selectedIndex + delta
    if (next < 0 || next > buttonIndex) { root.selectedIndex = -1; return }
    root.selectedIndex = next
  }

  readonly property bool moreResultsSelected: root.results.length > 0 && root.selectedIndex === root.results.length

  function selectedResult() {
    return root.selectedIndex >= 0 && root.selectedIndex < root.results.length
      ? root.results[root.selectedIndex] : null
  }

  // ---------- searching ----------

  // Only one curl runs at a time. `pendingQuery` is always the latest
  // debounced query; `activeQuery` is whichever one the running (or just
  // finished) curl was launched for. If they've diverged by the time a
  // response arrives, that response is for a query the user has since
  // moved on from — it's discarded and the current query is fetched
  // immediately after, rather than briefly showing stale results for an
  // older, shorter query typed while the network was slow.
  property string pendingQuery: ""
  property string activeQuery: ""

  function scheduleSearch() {
    debounceTimer.restart()
  }

  function runSearch() {
    var q = root.query.replace(/^\s+|\s+$/g, "")
    root.pendingQuery = q
    if (q.length < 2) {
      searchProc.running = false
      root.searching = false
      root.results = []
      root.errorText = ""
      root.selectedIndex = -1
      return
    }
    if (!searchProc.running) root.startSearch()
  }

  function startSearch() {
    root.activeQuery = root.pendingQuery
    root.searching = true
    root.errorText = ""
    // The path segment ahead of the filename is IMDb's own sharding scheme
    // (normally the query's first character) but the CDN serves identical
    // content regardless of what's there, so a constant "_" works for any
    // query including ones starting with digits or punctuation.
    var url = "https://sg.media-imdb.com/suggests/_/" + encodeURIComponent(root.activeQuery.toLowerCase()) + ".json"
    // fetch-suggest enforces a hard byte cap on the actual downloaded bytes
    // (not just a declared Content-Length), plus a response-status and
    // content-type check, before any of the body reaches this process —
    // the regex/JSONP-unwrap/JSON.parse below only ever runs over a small,
    // validated body. See fetch-poster for the same pattern applied to
    // poster downloads.
    searchProc.command = [root.fetchSuggestHelper, url]
    searchProc.running = true
  }

  Timer {
    id: debounceTimer
    interval: 250
    onTriggered: root.runSearch()
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.searching = false
        var forCurrentQuery = root.activeQuery === root.pendingQuery
        if (forCurrentQuery) {
          root.selectedIndex = -1
          var raw = String(text || "").trim()
          try {
            // Response is JSONP: imdb$<query>({...}) — strip everything
            // outside the outermost parens rather than trying to reproduce
            // IMDb's callback-naming rules.
            var jsonText = raw.replace(/^[^(]*\(/, "").replace(/\)\s*;?\s*$/, "")
            var data = JSON.parse(jsonText)
            var entries = (data && data.d) || []
            var mapped = []
            for (var i = 0; i < entries.length && mapped.length < 5; i++) {
              var e = entries[i]
              // Only real titles ("tt...") — the same endpoint also returns
              // people ("nm..."), companies, and franchises ("in...") mixed
              // into the same list.
              if (!e || !/^tt\d+$/.test(String(e.id || ""))) continue
              mapped.push({
                Title: String(e.l || ""),
                Year: e.y ? String(e.y) : "",
                imdbID: String(e.id),
                Poster: e.i && e.i[0] && root.isTrustedPosterUrl(e.i[0]) ? root.thumbUrl(e.i[0]) : "N/A"
              })
            }
            root.results = mapped
            root.errorText = mapped.length === 0 ? Strings.t("noResults") : ""
          } catch (e) {
            root.results = []
            root.errorText = Strings.t("searchFailed")
          }
        } else if (root.pendingQuery.length >= 2) {
          root.startSearch()
        }
        // else: the field dropped below 2 chars while this was in flight —
        // runSearch() already cleared results/errorText for that case.
      }
    }
  }

  onOpenedChanged: {
    if (opened) {
      // Reset on the way in, not the way out: clearing the results while
      // closing made the panel's content collapse out from under it while
      // it was still fading out (~140ms), a visible jump. Resetting here
      // instead means the fade-out plays over whatever was last shown, and
      // the panel is already blank by the time it's visible again.
      root.query = ""
      root.pendingQuery = ""
      root.activeQuery = ""
      root.results = []
      root.errorText = ""
      root.copiedImdbId = ""
      root.selectedIndex = -1
      root.showHelp = false
      if (searchField) searchField.text = ""
      Qt.callLater(function() { searchField.forceActiveFocus() })
    } else {
      debounceTimer.stop()
      copiedTimer.stop()
      searchProc.running = false
      root.searching = false
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    tooltipText: Strings.t("barTooltip")
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: searchField
    contentWidth: panel.fittedContentWidth(Style.space(380))
    // Cap is a safety ceiling (still bounded by the screen height below
    // it), not a tight fit — 560 was clipping the bottom padding off the
    // "Open search results" link with 5 results showing.
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        Item {
          width: parent.width
          height: Math.max(headerRow.implicitHeight, helpButton.implicitHeight)

          Row {
            id: headerRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              text: root.icon
              color: root.barForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: Strings.t("barTooltip")
              color: root.barForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          PanelActionButton {
            id: helpButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "\uf059" // nf-fa-question-circle
            tooltipText: root.showHelp ? Strings.t("hideShortcutsTooltip") : Strings.t("shortcutsTooltip")
            foreground: root.barForeground
            onClicked: root.showHelp = !root.showHelp
          }
        }

        PanelSeparator {
          foreground: root.barForeground
        }

        TextField {
          id: searchField
          width: parent.width
          foreground: root.barForeground
          placeholderText: Strings.t("searchPlaceholder")
          text: root.query
          // Hide the blinking caret while frozen (a result selected) —
          // otherwise the field still looks editable even though typing
          // is blocked.
          cursorVisible: activeFocus && root.selectedIndex < 0
          onTextChanged: {
            root.query = text
            root.selectedIndex = -1
            root.scheduleSearch()
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.close()
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Down) {
              root.moveSelection(1)
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Up) {
              root.moveSelection(-1)
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.moreResultsSelected) {
                root.openMoreResults()
                event.accepted = true
                return
              }
              if (root.selectedResult()) {
                root.openResult(root.selectedResult())
                event.accepted = true
                return
              }
            }
            if (event.key === Qt.Key_Space) {
              if (root.moreResultsSelected) {
                root.openMoreResults()
                event.accepted = true
                return
              }
              if (root.selectedResult()) {
                root.copyFolderName(root.selectedResult())
                event.accepted = true
                return
              }
            }
            // While a result is selected, the field is frozen: every other
            // key (typing, backspace, paste, ...) is swallowed instead of
            // editing the query out from under the selection. Up enough
            // times (or Escape) to get back to plain typing.
            if (root.selectedIndex >= 0) {
              event.accepted = true
            }
          }
        }

        Text {
          visible: root.query.length > 0 && root.query.replace(/^\s+|\s+$/g, "").length < 2
          width: parent.width
          text: Strings.t("minChars")
          color: Qt.darker(root.barForeground, 1.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Text {
          visible: root.searching
          width: parent.width
          text: Strings.t("searching")
          color: Qt.darker(root.barForeground, 1.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Text {
          visible: !root.searching && root.errorText !== ""
          width: parent.width
          text: root.errorText
          color: Color.urgent
          wrapMode: Text.WordWrap
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          visible: root.showHelp
          width: parent.width
          text: Strings.t("hint")
          color: Qt.darker(root.barForeground, 1.55)
          wrapMode: Text.WordWrap
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: !root.searching && root.results.length > 0

          Repeater {
            model: root.results
            ResultRow {
              required property var modelData
              required property int index
              width: parent.width
              item: modelData
              rowIndex: index
            }
          }
        }

        Button {
          visible: !root.searching && root.results.length > 0
          width: parent.width
          text: Strings.t("moreResults")
          foreground: root.barForeground
          fontFamily: Style.font.family
          fontSize: Style.font.caption
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          bordered: true
          selected: root.moreResultsSelected
          onClicked: root.openMoreResults()
        }
      }
    }
  }

  component ResultRow: Item {
    id: row
    property var item: null
    property int rowIndex: -1
    readonly property bool selected: rowIndex === root.selectedIndex
    readonly property string yearLabel: row.item ? root.startYear(row.item.Year) : ""

    implicitHeight: Math.max(poster.height, textCol.implicitHeight) + Style.space(10)

    // Populated once fetch-poster has downloaded and validated the poster
    // into the local cache; empty (no image shown) until then or if the
    // fetch fails.
    property string localPosterPath: ""

    function startPosterFetch() {
      row.localPosterPath = ""
      posterFetchProc.running = false
      if (!row.item || !row.item.Poster || row.item.Poster === "N/A") return
      var outPath = root.posterCachePath(row.item.imdbID)
      // Already proven cached by an earlier fetch this session — skip
      // spawning fetch-poster (a bash+curl process) entirely.
      if (root.posterCacheKnownGood[row.item.imdbID]) {
        row.localPosterPath = "file://" + outPath
        return
      }
      posterFetchProc.command = [root.fetchPosterHelper, row.item.Poster, outPath]
      posterFetchProc.__outPath = outPath
      posterFetchProc.__imdbID = row.item.imdbID
      posterFetchProc.running = true
    }

    // item: modelData at the call site already assigns a value during
    // construction, which fires this same onItemChanged — a separate
    // Component.onCompleted call here was spawning, then immediately
    // killing and respawning, an identical fetch-poster process per row.
    onItemChanged: row.startPosterFetch()

    Process {
      id: posterFetchProc
      property string __outPath: ""
      property string __imdbID: ""
      onExited: function(exitCode) {
        if (exitCode === 0) {
          row.localPosterPath = "file://" + posterFetchProc.__outPath
          root.posterCacheKnownGood[posterFetchProc.__imdbID] = true
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: row.selected ? Util.alpha(Color.accent, 0.18)
        : mouseArea.containsMouse ? Util.alpha(root.barForeground, 0.08) : "transparent"
    }

    Item {
      id: poster
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      width: Style.space(46)
      height: Style.space(68)

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Util.alpha(root.barForeground, 0.12)
        visible: posterImg.status !== Image.Ready
      }

      Text {
        anchors.centerIn: parent
        text: root.icon
        color: Qt.darker(root.barForeground, 1.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        visible: posterImg.status !== Image.Ready
      }

      Image {
        id: posterImg
        anchors.fill: parent
        source: row.localPosterPath
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        // Decode is capped independently of the (already byte-capped)
        // source file, at 2x the display box for HiDPI without ever
        // decoding at the original's full resolution.
        sourceSize.width: poster.width * 2
        sourceSize.height: poster.height * 2
        visible: status === Image.Ready
      }
    }

    Column {
      id: textCol
      anchors.left: poster.right
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(2)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: row.item ? (row.item.Title + (row.yearLabel ? " (" + row.yearLabel + ")" : "")) : ""
        color: root.barForeground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 2
      }

      Text {
        readonly property bool justCopied: row.item && row.item.imdbID === root.copiedImdbId
        width: parent.width
        textFormat: Text.PlainText
        text: justCopied ? Strings.t("copied") : (row.item ? root.folderName(row.item) : "")
        color: justCopied ? Color.accent : Qt.darker(root.barForeground, 1.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: justCopied
        wrapMode: Text.WordWrap
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (!row.item) return
        root.selectedIndex = row.rowIndex
        if (mouse.button === Qt.RightButton) root.copyFolderName(row.item)
        else root.openResult(row.item)
      }
    }
  }
}
