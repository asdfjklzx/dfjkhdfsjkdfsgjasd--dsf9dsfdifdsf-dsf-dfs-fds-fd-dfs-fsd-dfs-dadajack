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
    I = new Map();
  let S = !1;
  function x(r) {
    return ((new Date(r).getTime() - 14200704e5) * 4194304).toString();
  }
  async function P(r, s, c, u, t) {
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
  function z(r, s, c, u, t) {
    const d = e.storage.savedMessages || [];
    (d.push({
      id: u,
      channelId: r,
      userId: s,
      content: c,
      timestamp: t,
      createdAt: Date.now(),
    }),
      L(d));
  }
  function H(r) {
    (e.storage.savedMessages || [])
      .filter(function (s) {
        return s.channelId === r;
      })
      .forEach(function (s) {
        P(s.channelId, s.userId, s.content, s.timestamp, s.id);
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
  function parseLine(line) {
    const raw = (line || "").trim();
    if (!raw) return null;
    let m;
    if ((m = raw.match(/^(\S+)\s*\[([^\]]+)\]\s*[-\u2013\u2014|:]\s*([\s\S]*)$/)))
      return { uid: m[1], time: m[2].trim(), content: m[3] };
    if ((m = raw.match(/^(\S+)\s*[-\u2013\u2014|:]\s*([\s\S]*)$/)))
      return { uid: m[1], time: null, content: m[2] };
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
    for (const line of lines) {
      const parsed = parseLine(line);
      if (!parsed || !parsed.content.trim()) {
        fallback += 6e4;
        continue;
      }
      let uid = parsed.uid;
      /^(me|self)$/i.test(uid) && (uid = F.getCurrentUser()?.id);
      if (!uid) {
        fallback += 6e4;
        continue;
      }
      let iso = parsed.time ? parseTime(parsed.time, base, useUTC) : null;
      iso || (iso = new Date(fallback).toISOString());
      fallback += 6e4;
      const id = x(iso);
      (await P(ch, uid, parsed.content, iso, id), z(ch, uid, parsed.content, id, iso), count++);
    }
    tt(count ? `Sent ${count} message${count === 1 ? "" : "s"}.` : "No valid lines found.");
  }
  let D = null,
    T = null,
    E = [],
    b = null;
  var J = {
    onLoad() {
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
        n.React.createElement(
          N,
          { title: "Fake Message" },
          n.React.createElement(f, {
            title: "User ID (Optional)",
            placeholder: "Leave empty to use current user",
            value: r,
            onChange: function (o) {
              e.storage.userId = o || "";
            },
            helperText: c
              ? `User: ${c.username}`
              : r
                ? "User not found"
                : "Will use your account",
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
                (e.storage.message = ""));
            },
          }),
        ),
        n.React.createElement(
          N,
          { title: "Conversation Builder" },
          n.React.createElement(f, {
            title: "Conversation",
            placeholder:
              "One line each:\nuserId [time] - message\n\nExample:\n123456789 [9pm] - hey\n987654321 [9:01pm] - what's up\nme - lol nothing",
            value: e.storage.conversationText || "",
            onChange: function (o) {
              e.storage.conversationText = o || "";
            },
            multiline: !0,
          }),
          n.React.createElement(A, {
            label: "Build Conversation",
            subLabel:
              "Format: userId [time] - message. Use 'me' for yourself. Time is optional (9pm, 9:30am, 21:00, 2024-12-25 14:30); lines without a time are spaced 1 min apart. Honors the UTC toggle above.",
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
