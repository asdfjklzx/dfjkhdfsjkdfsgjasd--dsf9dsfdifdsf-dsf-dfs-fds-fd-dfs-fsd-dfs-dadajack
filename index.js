(function (U, n, l, v, e, y, B, k) {
  "use strict";
  const { FormSection: N, FormInput: f, FormRow: A } = v.Forms,
    F = l.findByProps("getCurrentUser", "getUser"),
    O = l.findByProps("getChannel", "getChannelId"),
    $ = l.findByProps("getChannelId", "getLastSelectedChannelId"),
    _ = l.findByProps("openLazy", "hideActionSheet"),
    w = l.findByProps("ActionSheetRow")?.ActionSheetRow ?? v.Forms.FormRow,
    G = l.findByStoreName("MessageStore"),
    j = l.findByStoreName("UserStore"),
    R = l.findByProps("sendMessage", "startEditMessage", "editMessage"),
    W = l.findByProps("showToast"),
    NV = l.findByProps("useNavigation"),
    I = new Map();
  let S = !1;
  function x(r) {
    return ((new Date(r).getTime() - 14200704e5) * 4194304).toString();
  }
  const resolving = new Set();
  function extractId(x) {
    try {
      if (!x) return null;
      if (typeof x === "string") return /^\d+$/.test(x) ? x : null;
      if (x.id) return x.id;
      if (x.userId) return x.userId;
      if (x.user && x.user.id) return x.user.id;
    } catch {}
    return null;
  }
  function resolveName(uid) {
    const prof = (e.storage.profiles || {})[uid];
    if (!prof) return null;
    if (prof.name) return prof.name;
    if (prof.sourceId && !resolving.has(uid)) {
      resolving.add(uid);
      try {
        const src = j.getUser(prof.sourceId);
        if (src)
          return src.globalName || src.global_name || src.username || null;
      } catch {
      } finally {
        resolving.delete(uid);
      }
    }
    return null;
  }
  function resolveAvatar(uid) {
    const prof = (e.storage.profiles || {})[uid];
    if (!prof) return null;
    if (prof.sourceId && !resolving.has(uid)) {
      resolving.add(uid);
      try {
        const src = j.getUser(prof.sourceId);
        if (src && typeof src.getAvatarURL === "function") {
          const u = src.getAvatarURL();
          if (u) return u;
        }
      } catch {
      } finally {
        resolving.delete(uid);
      }
    }
    return prof.avatar || null;
  }
  function mkAuthor(uid) {
    let u = null;
    try {
      u = j.getUser(uid);
    } catch {}
    const nm = resolveName(uid);
    const av = resolveAvatar(uid);
    return {
      id: uid,
      username: nm || (u ? u.username : "FakeUser"),
      global_name: nm || (u ? u.globalName || u.global_name || null : null),
      discriminator: u ? u.discriminator : "0001",
      avatar: av || (u ? u.avatar : null),
      bot: u ? u.bot : !1,
    };
  }
  async function P(r, s, c, u, t, ref) {
    const d = t || x(u || new Date().toISOString());
    try {
      const g = u || new Date().toISOString(),
        h = {
          id: d,
          type: 0,
          channel_id: r,
          author: mkAuthor(s),
          content: c,
          mentions: [],
          mention_roles: [],
          pinned: !1,
          tts: !1,
          attachments: [],
          embeds: [],
          timestamp: g,
          edited_timestamp: null,
          state: "SENT",
          fake: !0,
        };
      if (ref && ref.id) {
        h.type = 19;
        h.message_reference = { message_id: ref.id, channel_id: r };
        try {
          const gid = O?.getChannel?.(r)?.guild_id;
          if (gid) h.message_reference.guild_id = gid;
        } catch {}
        h.referenced_message = {
          id: ref.id,
          type: 0,
          channel_id: r,
          author: mkAuthor(ref.userId),
          content: ref.content,
          mentions: [],
          mention_roles: [],
          pinned: !1,
          tts: !1,
          attachments: [],
          embeds: [],
          timestamp: ref.timestamp || g,
          edited_timestamp: null,
          state: "SENT",
          fake: !0,
        };
      }
      n.FluxDispatcher.dispatch({
        type: "MESSAGE_CREATE",
        channelId: r,
        message: h,
        otherPluginBypass: !0,
      });
      try {
        n.FluxDispatcher.dispatch({
          type: "MESSAGE_ACK",
          channelId: r,
          messageId: d,
          manual: !0,
          immediate: !0,
        });
      } catch {}
      try {
        addLinkEmbeds(r, h, c);
      } catch {}
    } catch {}
  }
  function decodeEntities(str) {
    return ("" + str)
      .replace(/&amp;/g, "&")
      .replace(/&quot;/g, '"')
      .replace(/&#0?39;/g, "'")
      .replace(/&apos;/g, "'")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&#x2F;/gi, "/")
      .trim();
  }
  async function fetchT(url, ms, opts) {
    const ctl =
      typeof AbortController === "function" ? new AbortController() : null;
    const timer = ctl
      ? setTimeout(function () {
          try {
            ctl.abort();
          } catch {}
        }, ms || 8000)
      : null;
    try {
      return await fetch(
        url,
        Object.assign({}, opts, ctl ? { signal: ctl.signal } : {}),
      );
    } finally {
      if (timer) clearTimeout(timer);
    }
  }
  function metaTag(html, prop) {
    try {
      let m = html.match(
        new RegExp(
          '<meta[^>]+(?:property|name)=["\\\']' +
            prop +
            '["\\\'][^>]*?content=["\\\']([^"\\\']*)["\\\']',
          "i",
        ),
      );
      if (m && m[1]) return decodeEntities(m[1]);
      m = html.match(
        new RegExp(
          '<meta[^>]+content=["\\\']([^"\\\']*)["\\\'][^>]*?(?:property|name)=["\\\']' +
            prop +
            '["\\\']',
          "i",
        ),
      );
      if (m && m[1]) return decodeEntities(m[1]);
    } catch {}
    return null;
  }
  async function fetchYouTube(url) {
    try {
      const res = await fetchT(
        "https://www.youtube.com/oembed?format=json&url=" +
          encodeURIComponent(url),
        8000,
      );
      if (!res || !res.ok) return null;
      const data = await res.json();
      const embed = {
        type: "rich",
        url: url,
        color: 0xff0000,
        footer: { text: "YouTube" },
      };
      if (data.title) embed.title = ("" + data.title).slice(0, 256);
      if (data.author_name)
        embed.author = { name: data.author_name, url: data.author_url };
      if (data.thumbnail_url)
        embed.image = {
          url: data.thumbnail_url,
          proxy_url: data.thumbnail_url,
          width: data.thumbnail_width || 1280,
          height: data.thumbnail_height || 720,
        };
      return embed;
    } catch {
      return null;
    }
  }
  async function fetchOpenGraph(url) {
    try {
      const res = await fetchT(url, 8000, {
        headers: {
          Accept: "text/html,application/xhtml+xml",
          "User-Agent":
            "Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)",
        },
      });
      if (!res || !res.ok) return null;
      let html = await res.text();
      if (html && html.length > 6e5) html = html.slice(0, 6e5);
      const title =
        metaTag(html, "og:title") ||
        metaTag(html, "twitter:title") ||
        (function () {
          const m = html.match(/<title[^>]*>([^<]*)<\/title>/i);
          return m ? decodeEntities(m[1]) : null;
        })();
      const desc =
        metaTag(html, "og:description") ||
        metaTag(html, "twitter:description") ||
        metaTag(html, "description");
      const image =
        metaTag(html, "og:image") ||
        metaTag(html, "og:image:url") ||
        metaTag(html, "twitter:image");
      const site = metaTag(html, "og:site_name");
      if (!title && !desc && !image) return null;
      const embed = { type: "rich", url: url, color: 0x4f545c };
      if (title) embed.title = title.slice(0, 256);
      if (desc) embed.description = desc.slice(0, 350);
      if (site) embed.footer = { text: site };
      if (image)
        embed.image = {
          url: image,
          proxy_url: image,
        };
      return embed;
    } catch {
      return null;
    }
  }
  async function fetchOneEmbed(url) {
    try {
      if (
        /(?:youtube\.com\/watch\?|youtu\.be\/|youtube\.com\/shorts\/|youtube\.com\/embed\/)/i.test(
          url,
        )
      )
        return await fetchYouTube(url);
      if (/\.(png|jpe?g|gif|webp|bmp)(\?|#|$)/i.test(url))
        return {
          type: "image",
          url: url,
          image: { url: url, proxy_url: url },
        };
      return await fetchOpenGraph(url);
    } catch {
      return null;
    }
  }
  async function fetchEmbeds(content) {
    const out = [];
    try {
      const urls = ("" + (content || "")).match(/https?:\/\/[^\s<>]+/g) || [];
      const seen = {};
      for (let i2 = 0; i2 < urls.length && out.length < 4; i2++) {
        let url = urls[i2].replace(/[)\]\.,!?'"]+$/, "");
        if (seen[url]) continue;
        seen[url] = !0;
        const em = await fetchOneEmbed(url);
        if (em) out.push(em);
      }
    } catch {}
    return out;
  }
  function addLinkEmbeds(channelId, message, content) {
    try {
      if (e.storage.embedsEnabled === !1) return;
      if (!/https?:\/\//i.test("" + (content || ""))) return;
      fetchEmbeds(content)
        .then(function (embeds) {
          if (!embeds || !embeds.length) return;
          try {
            n.FluxDispatcher.dispatch({
              type: "MESSAGE_UPDATE",
              message: Object.assign({}, message, { embeds: embeds }),
              otherPluginBypass: !0,
            });
          } catch {}
        })
        .catch(function () {});
    } catch {}
  }
  function L(r) {
    ((e.storage.savedMessages = r), (e.storage._lastUpdate = Date.now()));
  }
  function z(r, s, c, u, t, ref) {
    const d = e.storage.savedMessages || [];
    const rec = {
      id: u,
      channelId: r,
      userId: s,
      content: c,
      timestamp: t,
      createdAt: Date.now(),
    };
    if (ref) rec.replyTo = ref;
    (d.push(rec), L(d));
  }
  function H(r) {
    (e.storage.savedMessages || [])
      .filter(function (s) {
        return s.channelId === r;
      })
      .forEach(function (s) {
        P(s.channelId, s.userId, s.content, s.timestamp, s.id, s.replyTo);
      });
  }
  function Y() {
    return $?.getChannelId() || O?.getChannelId?.() || null;
  }
  function tt(r) {
    try {
      W?.showToast?.(r);
    } catch {}
  }
  function mkISO(Y0, Mo, D0, H0, Mi, useUTC) {
    const dt = useUTC
      ? new Date(Date.UTC(Y0, Mo - 1, D0, H0, Mi, 0, 0))
      : new Date(Y0, Mo - 1, D0, H0, Mi, 0, 0);
    return isNaN(dt.getTime()) ? null : dt.toISOString();
  }
  function parseTime(str, base, useUTC) {
    const s = (str || "").trim();
    if (!s) return null;
    let m;
    if ((m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})[ T]+(\d{1,2}):(\d{2})$/)))
      return mkISO(+m[1], +m[2], +m[3], +m[4], +m[5], useUTC);
    if ((m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/)))
      return mkISO(+m[1], +m[2], +m[3], 0, 0, useUTC);
    if ((m = s.match(/^(\d{1,2})(?::(\d{2}))?\s*([ap]m)$/i))) {
      let H0 = +m[1];
      const Mi = m[2] ? +m[2] : 0,
        ap = m[3].toLowerCase();
      (ap === "pm" && H0 !== 12 && (H0 += 12), ap === "am" && H0 === 12 && (H0 = 0));
      return mkISO(base.y, base.mo, base.d, H0, Mi, useUTC);
    }
    if ((m = s.match(/^(\d{1,2}):(\d{2})$/)))
      return mkISO(base.y, base.mo, base.d, +m[1], +m[2], useUTC);
    return null;
  }
  function pRef(tok) {
    if (!tok) return null;
    const nn = tok.slice(1);
    return nn ? { line: parseInt(nn, 10) } : { prev: !0 };
  }
  function parseLine(line) {
    const raw = (line || "").trim();
    if (!raw) return null;
    let m;
    if (
      (m = raw.match(
        /^([^\s\[\^|:\-\u2013\u2014]+)\s*\[([^\]]+)\]\s*(\^\d*)?\s*[-\u2013\u2014|:]\s*([\s\S]*)$/,
      ))
    )
      return { uid: m[1], time: m[2].trim(), reply: pRef(m[3]), content: m[4] };
    if (
      (m = raw.match(
        /^([^\s\[\^|:\-\u2013\u2014]+)\s*(\^\d*)?\s*[-\u2013\u2014|:]\s*([\s\S]*)$/,
      ))
    )
      return { uid: m[1], time: null, reply: pRef(m[2]), content: m[3] };
    return null;
  }
  async function runConvo() {
    const ch = Y();
    if (!ch) {
      tt("No channel selected.");
      return;
    }
    const text = e.storage.conversationText || "",
      lines = text.split(/\r?\n/),
      useUTC = e.storage.useUTC || !1,
      now = new Date(),
      base = {
        y: e.storage.customYear || now.getFullYear(),
        mo: e.storage.customMonth || now.getMonth() + 1,
        d: e.storage.customDay || now.getDate(),
      };
    let count = 0,
      fallback = Date.now() - lines.length * 6e4;
    const built = [];
    for (const line of lines) {
      const parsed = parseLine(line);
      if (!parsed || !parsed.content.trim()) {
        fallback += 6e4;
        continue;
      }
      let uid = parsed.uid;
      if (/^(me|self)$/i.test(uid)) uid = F.getCurrentUser()?.id;
      else if (/^(them|they|user)$/i.test(uid)) uid = (e.storage.userId || "").trim();
      if (!uid) {
        fallback += 6e4;
        continue;
      }
      let iso = parsed.time ? parseTime(parsed.time, base, useUTC) : null;
      iso || (iso = new Date(fallback).toISOString());
      fallback += 6e4;
      const id = x(iso);
      let ref = null;
      if (parsed.reply) {
        const target = parsed.reply.prev
          ? built[built.length - 1]
          : built[parsed.reply.line - 1];
        if (target)
          ref = {
            id: target.id,
            userId: target.userId,
            content: target.content,
            timestamp: target.timestamp,
          };
      }
      (await P(ch, uid, parsed.content, iso, id, ref),
        z(ch, uid, parsed.content, id, iso, ref),
        built.push({
          id: id,
          userId: uid,
          content: parsed.content,
          timestamp: iso,
        }),
        count++);
    }
    tt(count ? `Sent ${count} message${count === 1 ? "" : "s"}.` : "No valid lines found.");
  }
  function closePanel(nav) {
    try {
      if (nav && typeof nav.goBack === "function") return void nav.goBack();
    } catch {}
    try {
      if (nav && typeof nav.pop === "function") return void nav.pop();
    } catch {}
    try {
      const N2 = l.findByProps("pop", "popToTop", "push");
      if (N2 && typeof N2.pop === "function") return void N2.pop();
    } catch {}
  }
  function PanelSheet() {
    const panel = n.React.createElement(J.settings, { inSheet: !0 });
    const RN = n.ReactNative || l.findByProps("ScrollView", "View");
    const spacer =
      RN && RN.View
        ? n.React.createElement(RN.View, { style: { height: 80 } })
        : null;
    let ActionSheet = null;
    try {
      ActionSheet =
        (l.findByProps("ActionSheet", "ActionSheetRow") || {}).ActionSheet ||
        (l.findByProps("ActionSheet") || {}).ActionSheet ||
        (l.findByProps("ActionSheetRow") || {}).ActionSheet ||
        null;
    } catch {}
    if (ActionSheet)
      return n.React.createElement(ActionSheet, {}, panel, spacer);
    if (!RN || !RN.ScrollView) return panel;
    let screenH = 800;
    try {
      if (RN.Dimensions && RN.Dimensions.get)
        screenH = RN.Dimensions.get("window").height || 800;
    } catch {}
    const sheetMax = Math.round(screenH * 0.88);
    return n.React.createElement(
      RN.View,
      {
        style: {
          backgroundColor: "#1e1f22",
          borderTopLeftRadius: 18,
          borderTopRightRadius: 18,
          paddingTop: 10,
          maxHeight: sheetMax,
        },
      },
      n.React.createElement(
        RN.ScrollView,
        {
          style: { maxHeight: sheetMax - 10 },
          contentContainerStyle: { paddingBottom: 240 },
          keyboardShouldPersistTaps: "handled",
          showsVerticalScrollIndicator: !0,
          nestedScrollEnabled: !0,
        },
        panel,
        spacer,
      ),
    );
  }
  function openPanel() {
    // Open as an action sheet (portal layer). The navigation push/modal path
    // crashes the app's root SafeAreaWrapper on some iOS clients, so we avoid
    // it entirely and use the action sheet system instead.
    try {
      if (_ && typeof _.openLazy === "function") {
        _.openLazy(
          Promise.resolve({ default: PanelSheet }),
          "LocalMessageSpooferSheet",
          {},
        );
        return;
      }
    } catch {}
    tt("Couldn't open the panel on this client. Open it from the Plugins list.");
  }
  function fillFromChat() {
    try {
      const ch = Y();
      if (!ch) return null;
      let channel = null;
      try {
        channel = O?.getChannel?.(ch);
      } catch {}
      if (!channel) {
        try {
          channel = l.findByStoreName("ChannelStore")?.getChannel?.(ch);
        } catch {}
      }
      // DM recipient first - works even with zero message history.
      let rec = channel?.recipients;
      if (rec && rec.length) {
        let id = rec[0];
        if (id && typeof id === "object") id = id.id || id.userId || id.user_id;
        if (id) return "" + id;
      }
      let raw = channel?.rawRecipients;
      if (raw && raw.length && raw[0]) {
        const id = raw[0].id || raw[0].user_id;
        if (id) return "" + id;
      }
      try {
        const ids = l.findByProps("getDMUserIds")?.getDMUserIds?.(ch);
        if (ids && ids.length) return "" + ids[0];
      } catch {}
      // Fallback: last message from someone other than you.
      let arr = [];
      try {
        const msgs = G?.getMessages?.(ch);
        arr =
          msgs && msgs.toArray ? msgs.toArray() : (msgs && msgs._array) || [];
      } catch {}
      const meId = j?.getCurrentUser?.()?.id;
      for (let i2 = arr.length - 1; i2 >= 0; i2--) {
        const au = arr[i2] && arr[i2].author && arr[i2].author.id;
        if (au && au !== meId) return "" + au;
      }
    } catch {}
    return null;
  }
  function clearSaved() {
    try {
      const count = (e.storage.savedMessages || []).length;
      L([]);
      tt(
        "Cleared " + count + " saved message" + (count === 1 ? "" : "s") + ".",
      );
    } catch {
      tt("Couldn't clear saved messages.");
    }
  }
  function saveProfile() {
    try {
      const id = ("" + (e.storage.profileId || "")).trim();
      if (!/^\d{5,}$/.test(id)) {
        tt("Enter a valid numeric user ID first.");
        return;
      }
      const name = ("" + (e.storage.profileName || "")).trim();
      const avatar = ("" + (e.storage.profileAvatar || "")).trim();
      const sourceId = ("" + (e.storage.profileSource || ""))
        .trim()
        .replace(/[^0-9]/g, "");
      if (!name && !avatar && !sourceId) {
        tt("Set a name, avatar URL, or a source user ID.");
        return;
      }
      if (sourceId && sourceId === id) {
        tt("Source ID must differ from the user ID.");
        return;
      }
      const p = Object.assign({}, e.storage.profiles || {});
      p[id] = {
        name: name || void 0,
        avatar: avatar || void 0,
        sourceId: sourceId || void 0,
      };
      e.storage.profiles = p;
      e.storage._lastUpdate = Date.now();
      tt(
        "Saved profile for " +
          id +
          (sourceId ? " (mirroring " + sourceId + ")" : "") +
          ".",
      );
    } catch {
      tt("Couldn't save that profile.");
    }
  }
  function removeProfile(id) {
    try {
      const key = ("" + (id || e.storage.profileId || "")).trim();
      const p = Object.assign({}, e.storage.profiles || {});
      if (!p[key]) {
        tt("No profile saved for that ID.");
        return;
      }
      delete p[key];
      e.storage.profiles = p;
      e.storage._lastUpdate = Date.now();
      tt("Removed profile for " + key + ".");
    } catch {
      tt("Couldn't remove that profile.");
    }
  }
  let D = null,
    T = null,
    E = [],
    b = null,
    K = [];
  var J = {
    onLoad() {
      try {
        K.forEach(function (fn) {
          try {
            fn();
          } catch {}
        });
      } catch {}
      K = [];
      try {
        const cmds = globalThis.vendetta?.commands;
        const reg =
          cmds && typeof cmds.registerCommand === "function"
            ? cmds.registerCommand.bind(cmds)
            : null;
        if (reg) {
          const u1 = reg({
            name: "spoofer",
            displayName: "spoofer",
            description: "Open the Local Message Spoofer panel.",
            displayDescription: "Open the Local Message Spoofer panel.",
            type: 1,
            inputType: 1,
            applicationId: "-1",
            options: [],
            execute: function () {
              openPanel();
            },
          });
          if (typeof u1 === "function") K.push(u1);
          const u2 = reg({
            name: "filluid",
            displayName: "filluid",
            description:
              "Fill the spoofer User ID from this chat, or pass a specific ID.",
            displayDescription:
              "Fill the spoofer User ID from this chat, or pass a specific ID.",
            type: 1,
            inputType: 1,
            applicationId: "-1",
            options: [
              {
                name: "userid",
                displayName: "userid",
                description: "Optional: a specific user ID to set.",
                displayDescription: "Optional: a specific user ID to set.",
                type: 3,
                required: !1,
              },
            ],
            execute: function (args) {
              try {
                const map = Array.isArray(args)
                  ? Object.fromEntries(
                      args.map(function (aa) {
                        return [aa?.name, aa?.value];
                      }),
                    )
                  : args ?? {};
                let id = ("" + (map.userid ?? "")).trim();
                if (!id) id = fillFromChat();
                if (id) {
                  e.storage.userId = id;
                  tt("User ID set: " + id);
                } else
                  tt("No user found here. Try: /filluid userid:123456789");
              } catch (err2) {
                tt("Couldn't set the User ID.");
              }
            },
          });
          if (typeof u2 === "function") K.push(u2);
          const u3 = reg({
            name: "clearfakes",
            displayName: "clearfakes",
            description: "Clear all saved fake messages (stops them replaying).",
            displayDescription:
              "Clear all saved fake messages (stops them replaying).",
            type: 1,
            inputType: 1,
            applicationId: "-1",
            options: [],
            execute: function () {
              clearSaved();
            },
          });
          if (typeof u3 === "function") K.push(u3);
        }
      } catch {}
      b = y.before("dispatch", n.FluxDispatcher, function (s) {
        const [c] = s;
        if (
          c.type === "MESSAGE_UPDATE" &&
          c.message?.fake &&
          !c.otherPluginBypass &&
          !S
        )
          return [];
      });
      try {
        const AV = l.findByProps("getUserAvatarURL");
        if (AV && typeof AV.getUserAvatarURL === "function")
          E.push(
            y.after("getUserAvatarURL", AV, function (a, ret) {
              try {
                const id = extractId(a && a[0]);
                if (id && (e.storage.profiles || {})[id]) {
                  const o = resolveAvatar(id);
                  if (o) return o;
                }
              } catch {}
              return ret;
            }),
          );
      } catch {}
      try {
        const AV2 = l.findByProps("getUserAvatarSource");
        if (AV2 && typeof AV2.getUserAvatarSource === "function")
          E.push(
            y.after("getUserAvatarSource", AV2, function (a, ret) {
              try {
                const id = extractId(a && a[0]);
                if (id && (e.storage.profiles || {})[id]) {
                  const o = resolveAvatar(id);
                  if (o) return Object.assign({}, ret, { uri: o });
                }
              } catch {}
              return ret;
            }),
          );
      } catch {}
      try {
        const GAV = l.findByProps("getGuildMemberAvatarURLSimple");
        if (GAV && typeof GAV.getGuildMemberAvatarURLSimple === "function")
          E.push(
            y.after("getGuildMemberAvatarURLSimple", GAV, function (a, ret) {
              try {
                const id = extractId(a && a[0]);
                if (id && (e.storage.profiles || {})[id]) {
                  const o = resolveAvatar(id);
                  if (o) return o;
                }
              } catch {}
              return ret;
            }),
          );
      } catch {}
      try {
        const cu = j && j.getCurrentUser && j.getCurrentUser();
        const proto = cu && cu.constructor && cu.constructor.prototype;
        if (proto && typeof proto.getAvatarURL === "function")
          E.push(
            y.after("getAvatarURL", proto, function (a, ret) {
              try {
                const id = this && this.id;
                if (id && (e.storage.profiles || {})[id]) {
                  const o = resolveAvatar(id);
                  if (o) return o;
                }
              } catch {}
              return ret;
            }),
          );
      } catch {}
      try {
        if (j && typeof j.getUser === "function")
          E.push(
            y.after("getUser", j, function (a, ret) {
              try {
                const profs = e.storage.profiles;
                const id = a && a[0];
                if (profs && id && profs[id] && ret) {
                  const nm = resolveName(id);
                  if (nm) {
                    if (ret.username !== nm) {
                      try {
                        ret.username = nm;
                      } catch {}
                    }
                    if (ret.globalName !== nm) {
                      try {
                        ret.globalName = nm;
                      } catch {}
                    }
                  }
                }
              } catch {}
              return ret;
            }),
          );
      } catch {}
      try {
        const GMS = l.findByStoreName("GuildMemberStore");
        if (GMS && typeof GMS.getNick === "function")
          E.push(
            y.after("getNick", GMS, function (a, ret) {
              try {
                const profs = e.storage.profiles;
                if (profs && a) {
                  const id = profs[a[1]] ? a[1] : profs[a[0]] ? a[0] : null;
                  if (id) {
                    const nm = resolveName(id);
                    if (nm) return nm;
                  }
                }
              } catch {}
              return ret;
            }),
          );
        if (GMS && typeof GMS.getMember === "function")
          E.push(
            y.after("getMember", GMS, function (a, ret) {
              try {
                const profs = e.storage.profiles;
                if (profs && a && ret) {
                  const id = profs[a[1]] ? a[1] : profs[a[0]] ? a[0] : null;
                  if (id) {
                    const nm = resolveName(id);
                    if (nm) {
                      if (ret.nick !== nm) {
                        try {
                          ret.nick = nm;
                        } catch {}
                      }
                      if ("nickname" in ret && ret.nickname !== nm) {
                        try {
                          ret.nickname = nm;
                        } catch {}
                      }
                    }
                  }
                }
              } catch {}
              return ret;
            }),
          );
      } catch {}
      try {
        const s = l.findByProps("openUserContextMenu");
        s?.openUserContextMenu &&
          (D = y.after("openUserContextMenu", s, function (c) {
            const u = c[0]?.userId || c[0]?.user?.id;
            u && (e.storage.userId = u);
          }));
      } catch {}
      try {
        T = n.FluxDispatcher.subscribe("CHANNEL_SELECT", function (s) {
          const c = s?.channelId;
          c &&
            setTimeout(function () {
              return H(c);
            }, 500);
        });
      } catch {}
      const r = Y();
      (r &&
        setTimeout(function () {
          return H(r);
        }, 1e3),
        E.push(
          y.before("openLazy", _, function ([s, c, u]) {
            const t = u?.message;
            c !== "MessageLongPressActionSheet" ||
              !t ||
              s.then(function (d) {
                const i = y.after("default", d, function (g, h) {
                  setTimeout(i, 0);
                  const M = k.findInReactTree(h, function (m) {
                    return m?.[0]?.type?.name === "ActionSheetRow";
                  });
                  if (!M) return;
                  const o = j.getCurrentUser(),
                    a = G.getMessage(t.channel_id, t.id) ?? t;
                  if (
                    a.author.id === o.id ||
                    M.some(function (m) {
                      return m?.props?.label === "Edit Locally";
                    })
                  )
                    return;
                  const p = Math.max(
                      M.findIndex(function (m) {
                        return m.props.message === n.i18n.Messages.MARK_UNREAD;
                      }),
                      0,
                    ),
                    C = function () {
                      ((S = !0),
                        I.has(a.id) ||
                          I.set(a.id, JSON.parse(JSON.stringify(a))),
                        _.hideActionSheet(),
                        R.startEditMessage(a.channel_id, a.id, a.content));
                    };
                  M.splice(
                    p,
                    0,
                    n.React.createElement(w, {
                      label: "Edit Locally",
                      icon: n.React.createElement(w.Icon, {
                        source: B.getAssetIDByName("ic_edit_24px"),
                      }),
                      onPress: C,
                    }),
                  );
                  M.splice(
                    p,
                    0,
                    n.React.createElement(w, {
                      label: "Use as Fake User",
                      icon: n.React.createElement(w.Icon, {
                        source: B.getAssetIDByName("ic_members"),
                      }),
                      onPress: function () {
                        try {
                          e.storage.userId = a.author.id;
                          _.hideActionSheet();
                          tt(
                            "Fake user set: " +
                              (a.author.username || a.author.id),
                          );
                        } catch {}
                      },
                    }),
                  );
                });
              });
          }),
        ),
        E.push(
          y.before("editMessage", R, function (s) {
            const [c, u, t] = s;
            if (S) {
              const d = I.get(u);
              if (!d) return;
              const i = e.storage.savedMessages || [],
                g = i.find(function (h) {
                  return h.id === u;
                });
              return (
                g && ((g.content = t.content), L(i)),
                n.FluxDispatcher.dispatch({
                  type: "MESSAGE_UPDATE",
                  message: { ...d, content: t.content, edited_timestamp: null },
                  otherPluginBypass: !0,
                }),
                []
              );
            }
          }),
        ),
        E.push(
          y.after("endEditMessage", R, function () {
            S && (S = !1);
          }),
        ));
    },
    onUnload() {
      try {
        K.forEach(function (fn) {
          try {
            fn();
          } catch {}
        });
      } catch {}
      K = [];
      (D && (D(), (D = null)),
        T && (n.FluxDispatcher.unsubscribe("CHANNEL_SELECT", T), (T = null)),
        b && (b(), (b = null)),
        E.forEach(function (r) {
          return r();
        }),
        (E = []),
        I.clear());
    },
    settings: function (props) {
      const [tick, setTick] = n.React.useState(0);
      let nav = null;
      try {
        if (NV && NV.useNavigation) nav = NV.useNavigation();
      } catch {}
      const r = e.storage.userId || "",
        s = e.storage.message || "",
        c = r ? F.getUser(r) : null,
        u = (e.storage.savedMessages || []).length,
        pid = e.storage.profileId || "",
        pname = e.storage.profileName || "",
        pavatar = e.storage.profileAvatar || "",
        psource = e.storage.profileSource || "",
        profs = e.storage.profiles || {},
        profKeys = Object.keys(profs),
        t = new Date(),
        d = e.storage.customYear || t.getFullYear(),
        i = e.storage.customMonth || t.getMonth() + 1,
        g = e.storage.customDay || t.getDate(),
        h =
          e.storage.customHour !== void 0 ? e.storage.customHour : t.getHours(),
        M =
          e.storage.customMinute !== void 0
            ? e.storage.customMinute
            : t.getMinutes();
      return n.React.createElement(
        props && props.inSheet ? n.React.Fragment : v.Forms.Form,
        {},
        n.React.createElement(A, {
          label: "Close Panel",
          leading: A.Icon
            ? n.React.createElement(A.Icon, {
                source: B.getAssetIDByName("ic_close"),
              })
            : void 0,
          onPress: function () {
            if (props && props.inSheet) {
              try {
                _.hideActionSheet();
              } catch {}
            } else {
              closePanel(nav);
            }
          },
        }),
        n.React.createElement(
          N,
          { title: "Fake Message" },
          n.React.createElement(f, {
            key: "uid" + tick,
            title: "User ID (Optional)",
            placeholder: "Leave empty to use current user",
            value: r,
            onChange: function (o) {
              e.storage.userId = o || "";
            },
            helperText: c
              ? `User: ${c.username} - use "them" in the builder`
              : r
                ? 'User not found (still usable as "them")'
                : "Will use your account",
          }),
          n.React.createElement(A, {
            label: "Fill from current chat",
            subLabel:
              "Grab the other person in this DM (or the last sender in this channel).",
            leading: A.Icon
              ? n.React.createElement(A.Icon, {
                  source: B.getAssetIDByName("ic_members"),
                })
              : void 0,
            onPress: function () {
              const id = fillFromChat();
              if (id) {
                e.storage.userId = id;
                setTick(function (kk) {
                  return kk + 1;
                });
                tt("Filled User ID: " + id);
              } else
                tt(
                  'Couldn\'t find a user here. Open a DM, or long-press a message and pick "Use as Fake User".',
                );
            },
          }),
          n.React.createElement(f, {
            title: "Message",
            placeholder: "Enter message content",
            value: s,
            onChange: function (o) {
              e.storage.message = o || "";
            },
            multiline: !0,
          }),
          n.React.createElement(A, {
            label: "Link Previews",
            subLabel:
              "Show embeds for links in fake messages (YouTube, websites, images).",
            trailing: n.React.createElement(v.Forms.FormSwitch, {
              value: e.storage.embedsEnabled !== !1,
              onValueChange: function (o) {
                e.storage.embedsEnabled = o;
              },
            }),
          }),
        ),
        n.React.createElement(
          N,
          { title: "Custom Timestamp" },
          n.React.createElement(A, {
            label: e.storage.useUTC ? "Using UTC Time" : "Using Local Time",
            subLabel: e.storage.useUTC
              ? "Time will be the same for everyone"
              : "Time will adjust to viewer's timezone",
            trailing: n.React.createElement(v.Forms.FormSwitch, {
              value: e.storage.useUTC || !1,
              onValueChange: function (o) {
                e.storage.useUTC = o;
              },
            }),
          }),
          n.React.createElement(f, {
            title: "Year",
            placeholder: "YYYY (e.g., 2024)",
            value: String(d),
            onChange: function (o) {
              const a = parseInt(o);
              e.storage.customYear = isNaN(a) ? t.getFullYear() : a;
            },
            keyboardType: "number-pad",
          }),
          n.React.createElement(f, {
            title: "Month",
            placeholder: "1-12",
            value: String(i),
            onChange: function (o) {
              const a = parseInt(o);
              e.storage.customMonth = isNaN(a)
                ? t.getMonth() + 1
                : Math.min(Math.max(a, 1), 12);
            },
            keyboardType: "number-pad",
          }),
          n.React.createElement(f, {
            title: "Day",
            placeholder: "1-31",
            value: String(g),
            onChange: function (o) {
              const a = parseInt(o);
              e.storage.customDay = isNaN(a)
                ? t.getDate()
                : Math.min(Math.max(a, 1), 31);
            },
            keyboardType: "number-pad",
          }),
          n.React.createElement(f, {
            title: "Hour",
            placeholder: "0-23",
            value: String(h),
            onChange: function (o) {
              const a = parseInt(o);
              e.storage.customHour = isNaN(a)
                ? t.getHours()
                : Math.min(Math.max(a, 0), 23);
            },
            keyboardType: "number-pad",
          }),
          n.React.createElement(f, {
            title: "Minute",
            placeholder: "0-59",
            value: String(M),
            onChange: function (o) {
              const a = parseInt(o);
              e.storage.customMinute = isNaN(a)
                ? t.getMinutes()
                : Math.min(Math.max(a, 0), 59);
            },
            keyboardType: "number-pad",
          }),
          n.React.createElement(A, {
            label: "Send Fake Message",
            subLabel: `${u} messages saved | Timestamp: ${d}-${String(i).padStart(2, "0")}-${String(g).padStart(2, "0")} ${String(h).padStart(2, "0")}:${String(M).padStart(2, "0")}`,
            onPress: async function () {
              const o = Y(),
                a = (e.storage.message || "").trim();
              if (!a || !o) return;
              const p =
                (e.storage.userId || "").trim() || F.getCurrentUser()?.id;
              if (!p) return;
              const C = (
                  e.storage.useUTC
                    ? new Date(
                        Date.UTC(
                          e.storage.customYear || t.getFullYear(),
                          (e.storage.customMonth || t.getMonth() + 1) - 1,
                          e.storage.customDay || t.getDate(),
                          e.storage.customHour !== void 0
                            ? e.storage.customHour
                            : t.getHours(),
                          e.storage.customMinute !== void 0
                            ? e.storage.customMinute
                            : t.getMinutes(),
                          0,
                          0,
                        ),
                      )
                    : new Date(
                        e.storage.customYear || t.getFullYear(),
                        (e.storage.customMonth || t.getMonth() + 1) - 1,
                        e.storage.customDay || t.getDate(),
                        e.storage.customHour !== void 0
                          ? e.storage.customHour
                          : t.getHours(),
                        e.storage.customMinute !== void 0
                          ? e.storage.customMinute
                          : t.getMinutes(),
                        0,
                        0,
                      )
                ).toISOString(),
                m = x(C);
              (await P(o, p, a, C, m),
                z(o, p, a, m, C),
                tt("Fake message sent."));
            },
          }),
        ),
        n.React.createElement(
          N,
          { title: "Conversation Builder" },
          n.React.createElement(f, {
            title: "Conversation",
            placeholder:
              "One line each:\nuserId [time] [^reply] - message\n\nme = you  |  them = the User ID above\n^N = reply to line N  |  ^ = reply to previous\n\nExample:\nme [9pm] - hey\nthem [9:01pm] ^1 - hi back\nme ^ - lol",
            value: e.storage.conversationText || "",
            onChange: function (o) {
              e.storage.conversationText = o || "";
            },
            multiline: !0,
          }),
          n.React.createElement(A, {
            label: "Build Conversation",
            subLabel:
              "Format: userId [time] [^reply] - message. 'me' = you, 'them' = the User ID above. Reply with ^N (the Nth message) or ^ (previous message). Time optional (9pm, 21:00, 2024-12-25 14:30); untimed lines are spaced 1 min apart. Honors the UTC toggle.",
            onPress: async function () {
              await runConvo();
            },
          }),
        ),
        n.React.createElement(
          N,
          { title: "Fake Profiles" },
          n.React.createElement(A, {
            label:
              "Override a user ID's display name and avatar across the app (chat, profiles, server member lists). Either set a name/avatar, or mirror another user's profile.",
          }),
          n.React.createElement(f, {
            title: "User ID",
            placeholder: "User ID to customize",
            value: pid,
            onChange: function (o) {
              e.storage.profileId = (o || "").replace(/[^0-9]/g, "");
            },
            keyboardType: "number-pad",
          }),
          n.React.createElement(f, {
            title: "Display Name",
            placeholder: "Name to show (optional)",
            value: pname,
            onChange: function (o) {
              e.storage.profileName = o || "";
            },
          }),
          n.React.createElement(f, {
            title: "Avatar URL",
            placeholder: "https://... image link (optional)",
            value: pavatar,
            onChange: function (o) {
              e.storage.profileAvatar = o || "";
            },
          }),
          n.React.createElement(f, {
            title: "Copy From User ID",
            placeholder: "Mirror this user's name + pfp (optional)",
            value: psource,
            onChange: function (o) {
              e.storage.profileSource = (o || "").replace(/[^0-9]/g, "");
            },
            keyboardType: "number-pad",
          }),
          n.React.createElement(A, {
            label: "Save Profile",
            onPress: function () {
              saveProfile();
              setTick(function (kk) {
                return kk + 1;
              });
            },
          }),
          n.React.createElement(A, {
            label: "Remove This Profile",
            subLabel: "Deletes the profile for the User ID above.",
            leading: A.Icon
              ? n.React.createElement(A.Icon, {
                  source: B.getAssetIDByName("ic_trash_24px"),
                })
              : void 0,
            onPress: function () {
              removeProfile();
              setTick(function (kk) {
                return kk + 1;
              });
            },
          }),
          profKeys.length
            ? n.React.createElement(A, {
                label: "Saved profiles (" + profKeys.length + ") - tap to edit:",
              })
            : null,
          profKeys.map(function (k) {
            const pr = profs[k] || {};
            return n.React.createElement(A, {
              key: k,
              label: (pr.name || (pr.sourceId ? "(mirror)" : "(no name)")) + "  -  " + k,
              subLabel: pr.sourceId
                ? "Mirrors user " + pr.sourceId
                : pr.avatar
                  ? "Custom avatar set"
                  : "Name only",
              onPress: function () {
                ((e.storage.profileId = k),
                  (e.storage.profileName = pr.name || ""),
                  (e.storage.profileAvatar = pr.avatar || ""),
                  (e.storage.profileSource = pr.sourceId || ""));
                setTick(function (kk) {
                  return kk + 1;
                });
              },
            });
          }),
        ),
        n.React.createElement(
          N,
          { title: "Saved Messages" },
          n.React.createElement(A, {
            label: "Clear Saved Messages",
            subLabel:
              u +
              " saved. These replay each time you reopen a channel - clearing stops that.",
            leading: A.Icon
              ? n.React.createElement(A.Icon, {
                  source: B.getAssetIDByName("ic_trash_24px"),
                })
              : void 0,
            onPress: function () {
              clearSaved();
              setTick(function (kk) {
                return kk + 1;
              });
            },
          }),
        ),
      );
    },
  };
  return (
    (U.default = J),
    Object.defineProperty(U, "__esModule", { value: !0 }),
    U
  );
})(
  {},
  vendetta.metro.common,
  vendetta.metro,
  vendetta.ui.components,
  vendetta.plugin,
  vendetta.patcher,
  vendetta.ui.assets,
  vendetta.utils,
);
