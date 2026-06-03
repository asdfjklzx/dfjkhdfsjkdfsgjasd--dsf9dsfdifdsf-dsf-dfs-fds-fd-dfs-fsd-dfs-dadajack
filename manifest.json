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
  async function P(r, s, c, u, t, ref) {
    const d = t || x(u || new Date().toISOString());
    try {
      const i = F.getUser(s),
        g = u || new Date().toISOString(),
        h = {
          id: d,
          type: 0,
          channel_id: r,
          author: {
            id: s,
            username: i ? i.username : "FakeUser",
            discriminator: i ? i.discriminator : "0001",
            avatar: i ? i.avatar : null,
            bot: i ? i.bot : !1,
          },
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
        const ri = F.getUser(ref.userId);
        h.referenced_message = {
          id: ref.id,
          type: 0,
          channel_id: r,
          author: {
            id: ref.userId,
            username: ri ? ri.username : "FakeUser",
            discriminator: ri ? ri.discriminator : "0001",
            avatar: ri ? ri.avatar : null,
            bot: ri ? ri.bot : !1,
          },
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
          type: "CHANNEL_UPDATE",
          channel: { id: r, last_message_id: d },
        });
      } catch {}
      try {
        n.FluxDispatcher.dispatch({
          type: "MESSAGE_ACK",
          channelId: r,
          messageId: d,
          manual: !0,
          immediate: !0,
        });
      } catch {}
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
  function openPanel() {
    const renderFn = function () {
      return n.React.createElement(J.settings);
    };
    const params = { render: renderFn, title: "Message Spoofer" };
    let routes = ["VendettaCustomPage", "BunnyCustomPage", "RevengeCustomPage"];
    try {
      if (typeof globalThis !== "undefined" && globalThis.bunny)
        routes = ["BunnyCustomPage", "VendettaCustomPage", "RevengeCustomPage"];
      else if (typeof globalThis !== "undefined" && globalThis.revenge)
        routes = ["RevengeCustomPage", "VendettaCustomPage", "BunnyCustomPage"];
    } catch {}
    try {
      const Nav = l.findByProps("push", "pop", "popToTop");
      if (Nav && typeof Nav.push === "function") {
        for (const route of routes) {
          try {
            Nav.push(route, params);
            return;
          } catch {}
        }
      }
    } catch {}
    try {
      const Nav2 = l.findByProps("pushLazy");
      if (Nav2 && typeof Nav2.pushLazy === "function") {
        Nav2.pushLazy(
          Promise.resolve({ default: J.settings }),
          "LocalMessageSpoofer",
          {},
        );
        return;
      }
    } catch {}
    tt("Couldn't open the panel automatically. Open it from Plugins settings.");
  }
  function fillFromChat() {
    try {
      const ch = Y();
      if (!ch) return null;
      const channel = O?.getChannel?.(ch);
      let rec = channel?.recipients;
      if (rec && rec.length) {
        let id = rec[0];
        if (id && typeof id === "object") id = id.id || id.userId || id.user_id;
        if (id) return "" + id;
      }
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
  let D = null,
    T = null,
    E = [],
    b = null,
    K = [];
  var J = {
    onLoad() {
      try {
        const reg = globalThis.vendetta?.commands?.registerCommand;
        if (typeof reg === "function") {
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
    settings: function () {
      const [tick, setTick] = n.React.useState(0);
      let nav = null;
      try {
        if (NV && NV.useNavigation) nav = NV.useNavigation();
      } catch {}
      const r = e.storage.userId || "",
        s = e.storage.message || "",
        c = r ? F.getUser(r) : null,
        u = (e.storage.savedMessages || []).length,
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
        v.Forms.Form,
        {},
        n.React.createElement(A, {
          label: "Close Panel",
          leading: A.Icon
            ? n.React.createElement(A.Icon, {
                source: B.getAssetIDByName("ic_close"),
              })
            : void 0,
          onPress: function () {
            closePanel(nav);
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
