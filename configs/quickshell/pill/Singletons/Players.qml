pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland

/**
 * Single now-playing source for the media surface, source switcher and OSD, preferring the player last picked by hand.
 */
Singleton {
    id: root

    function isProxy(p) {
        return (p && p.dbusName ? p.dbusName : "").toLowerCase().indexOf("playerctld") >= 0;
    }

    function isIdle(p) {
        if (!p || isProxy(p))
            return true;
        return !p.isPlaying && (!p.trackTitle || p.trackTitle.length === 0);
    }

    function otherPlaying(self) {
        var l = root.list;
        for (var i = 0; i < l.length; i++)
            if (l[i] !== self && l[i].isPlaying)
                return true;
        return false;
    }

    readonly property var list: {
        var all = Mpris.players.values;
        var out = [];
        for (var i = 0; i < all.length; i++)
            if (all[i] && !isProxy(all[i]))
                out.push(all[i]);
        return out;
    }

    readonly property var pickable: {
        var l = root.list;
        var out = [];
        for (var i = 0; i < l.length; i++)
            if (!isIdle(l[i]))
                out.push(l[i]);
        return out;
    }

    property var manualActive: null
    property var preferred: null

    property bool ready: false
    Component.onCompleted: {
        ready = true;
        resolveTwitch();
        resolveNetflix();
    }

    onListChanged: {
        if (manualActive && list.indexOf(manualActive) < 0)
            manualActive = null;
        if (preferred && list.indexOf(preferred) < 0)
            preferred = null;
    }

    /**
     * A playing player always wins, and only when nothing plays is the paused preferred held, so a paused background tab never takes the surface.
     */
    readonly property var autoPick: {
        var l = root.list;
        if (l.length === 0)
            return null;
        if (preferred && l.indexOf(preferred) >= 0 && preferred.isPlaying)
            return preferred;
        for (var i = 0; i < l.length; i++)
            if (l[i].isPlaying && !isIdle(l[i]))
                return l[i];
        if (preferred && l.indexOf(preferred) >= 0 && !isIdle(preferred))
            return preferred;
        for (var j = 0; j < l.length; j++)
            if (!isIdle(l[j]) && l[j].trackTitle)
                return l[j];
        return l[0];
    }

    readonly property var active: (manualActive && list.indexOf(manualActive) >= 0 && !isIdle(manualActive)) ? manualActive : autoPick

    function select(p) {
        root.manualActive = (p && list.indexOf(p) >= 0) ? p : null;
    }

    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            required property var modelData
            readonly property bool real: modelData && !Players.isProxy(modelData)
            readonly property bool playing: real ? modelData.isPlaying : false
            readonly property string title: real && modelData.trackTitle ? modelData.trackTitle : ""

            onPlayingChanged: {
                if (!Players.ready)
                    return;
                if (playing) {
                    if (!Players.isIdle(modelData) && !Players.otherPlaying(modelData))
                        Players.preferred = modelData;
                    Players.announce(modelData);
                } else if (modelData === Players.active) {
                    Players.announce(modelData);
                }
            }
            /**
             * Browser DRM players (Netflix in Brave) set the title while isPlaying still reads false, so any real title announces.
             */
            onTitleChanged: {
                if (Players.ready && title.length > 0 && (playing || modelData === Players.active))
                    Players.announce(modelData);
            }
        }
    }

    readonly property bool has: active !== null
    readonly property bool playing: has && active.isPlaying
    /** Falls back to the service label so a titleless DRM stream still reads as its site. */
    readonly property string title: has ? refineTitle(active, active.trackTitle || labelOf(active)) : ""
    readonly property string artist: has ? Theme.joinArtists(active.trackArtists, active.trackArtist) : ""
    readonly property string trackUrl: urlOf(active)
    readonly property string artUrl: artUrlFor(active)
    readonly property real lengthSec: has && active.length > 0 ? active.length : 0
    /** A bogus near-INT64 length is how live streams report "no end". */
    readonly property bool live: has && (lengthSec <= 0 || lengthSec > 86400)
    readonly property string source: serviceOf(active)
    readonly property string serviceLabel: source.length > 0
        ? source.charAt(0).toUpperCase() + source.slice(1) : ""

    /** Browsers reuse one art path per video, so fold player and title in to catch a new song. */
    function keyFor(p) {
        return p ? ((p.dbusName || "") + "|" + (p.trackTitle || "") + "|" + artUrlFor(p)) : "";
    }
    readonly property string trackKey: has ? keyFor(active) : ""

    /**
     * Fires for any player, not only the active one, so starting a video over your music still flashes the OSD.
     */
    signal announce(var player)

    function urlOf(p) {
        return (p && p.metadata) ? (p.metadata["xesam:url"] || "") : "";
    }

    function serviceOf(p) {
        if (!p)
            return "";
        var site = siteName(urlOf(p));
        if (site.length === 0)
            site = siteFromTitle(p.trackTitle ? p.trackTitle : "");
        if (site.length > 0)
            return site;
        var n = p.identity ? p.identity : (p.desktopEntry ? p.desktopEntry : "");
        return n.toLowerCase();
    }

    function labelOf(p) {
        var s = serviceOf(p);
        if (s.length > 0)
            return s.charAt(0).toUpperCase() + s.slice(1);
        return p && p.identity ? p.identity : "";
    }

    function nowPlayingFor(p) {
        return p && p.trackTitle ? p.trackTitle : "";
    }

    /**
     * Matches the player to its desktop entry with the tray's window-to-entry pass, falling back to a direct icon-theme lookup.
     */
    function appIconFor(p) {
        if (!p)
            return "";
        var id = (p.desktopEntry && p.desktopEntry.length > 0) ? p.desktopEntry : (p.identity || "");
        if (id.length === 0)
            return "";
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === id.toLowerCase() && e.icon)
                return Quickshell.iconPath(e.icon, "application-x-executable");
        }
        return Quickshell.iconPath(id.toLowerCase(), "application-x-executable");
    }

    function artUrlFor(p) {
        if (!p)
            return "";
        if (p.trackArtUrl)
            return p.trackArtUrl;
        var u = urlOf(p);
        if (p === active && twitchAvatar.length > 0 && isTwitch(u))
            return twitchAvatar;
        var nid = netflixIdOf(u);
        if (nid.length > 0 && nid === netflixId && netflixArt.length > 0)
            return netflixArt;
        return derivedThumb(u);
    }

    function siteName(url) {
        var m = url.match(/^https?:\/\/(?:www\.)?([^\/]+)/);
        if (!m)
            return "";
        var host = m[1].toLowerCase();
        if (host === "youtu.be")
            return "youtube";
        var parts = host.split(".");
        return parts.length >= 2 ? parts[parts.length - 2] : parts[0];
    }

    /** Browsers with no page url tag the site onto the title ("... | Spotify"); trust only known sites. */
    function siteFromTitle(t) {
        var m = t.match(/[|\-–—]\s*([A-Za-z][A-Za-z0-9]+)\s*$/);
        if (!m)
            return "";
        var s = m[1].toLowerCase();
        var known = { youtube: 1, spotify: 1, twitch: 1, soundcloud: 1, bandcamp: 1 };
        return known[s] ? s : "";
    }

    function youtubeId(url) {
        var m = url.match(/^https?:\/\/(?:www\.|m\.|music\.)?youtube\.com\/watch\?(?:.*&)?v=([\w-]{11})/)
            || url.match(/^https?:\/\/youtu\.be\/([\w-]{11})/);
        return m ? m[1] : "";
    }

    function twitchChannelOf(url) {
        var m = url.match(/^https?:\/\/(?:www\.)?twitch\.tv\/([^\/?#]+)/);
        if (!m)
            return "";
        var ch = m[1].toLowerCase();
        var reserved = { videos: 1, directory: 1, u: 1, p: 1, settings: 1, subscriptions: 1, following: 1, downloads: 1 };
        return reserved[ch] ? "" : ch;
    }

    function isTwitch(url) {
        return twitchChannelOf(url).length > 0;
    }

    function derivedThumb(url) {
        var yid = youtubeId(url);
        if (yid)
            return "https://img.youtube.com/vi/" + yid + "/mqdefault.jpg";
        var ch = twitchChannelOf(url);
        if (ch)
            return "https://static-cdn.jtvnw.net/previews-ttv/live_user_" + ch + "-320x180.jpg";
        return "";
    }

    /**
     * Netflix MPRIS only reports the title "Netflix" with no art, so the real name and cover come from the public title page's og:title and og:image.
     */
    property string netflixName: ""
    property string netflixArt: ""
    property string netflixId: ""

    function netflixIdOf(url) {
        var m = url.match(/^https?:\/\/(?:www\.)?netflix\.com\/(?:watch|title)\/(\d+)/);
        return m ? m[1] : "";
    }

    function resolveNetflix() {
        var id = netflixIdOf(trackUrl);
        if (id === netflixId)
            return;
        netflixId = id;
        netflixName = "";
        netflixArt = "";
        if (id.length === 0)
            return;
        var xhr = new XMLHttpRequest();
        xhr.timeout = 8000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200 || root.netflixId !== id)
                return;
            var t = xhr.responseText.match(/property="og:title"\s+content="([^"]+)"|og:title"\s+content="([^"]+)"/);
            var i = xhr.responseText.match(/property="og:image"\s+content="([^"]+)"|og:image"\s+content="([^"]+)"/);
            var name = t ? (t[1] || t[2] || "") : "";
            name = name.replace(/^Watch\s+/i, "").replace(/\s*\|\s*Netflix\s*$/i, "");
            if (name.length > 0)
                root.netflixName = name;
            var img = i ? (i[1] || i[2] || "") : "";
            if (img.indexOf("https:") === 0)
                root.netflixArt = img;
        };
        xhr.open("GET", "https://www.netflix.com/title/" + id);
        xhr.send();
    }

    /** Swaps a stub browser title for the resolved show name where one exists. */
    function refineTitle(p, raw) {
        if (p && netflixId.length > 0 && netflixName.length > 0
            && netflixIdOf(urlOf(p)) === netflixId
            && (!raw || raw === "Netflix"))
            return netflixName;
        return raw;
    }

    /** Twitch exposes no MPRIS art; resolve the streamer avatar async, live preview stands in. */
    property string twitchAvatar: ""
    property string twitchChannel: ""
    onTrackUrlChanged: {
        resolveTwitch();
        resolveNetflix();
    }

    function resolveTwitch() {
        var ch = twitchChannelOf(trackUrl);
        if (ch === twitchChannel)
            return;
        twitchChannel = ch;
        twitchAvatar = "";
        if (ch.length === 0)
            return;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                var r = xhr.responseText.trim();
                if (r.indexOf("https:") === 0 && r.length > 12 && root.twitchChannel === ch)
                    root.twitchAvatar = r;
            }
        };
        xhr.open("GET", "https://decapi.me/twitch/avatar/" + ch);
        xhr.send();
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "mediaToggle"
        description: "Play or pause the active media player"
        onPressed: { var a = root.active; if (a && a.canTogglePlaying) a.togglePlaying(); }
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "mediaNext"
        description: "Skip to the next track"
        onPressed: { var a = root.active; if (a && a.canGoNext) a.next(); }
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "mediaPrev"
        description: "Skip to the previous track"
        onPressed: { var a = root.active; if (a && a.canGoPrevious) a.previous(); }
    }
}
