// Canal de presència global per a jugadors online.
// Usa Supabase Realtime Presence: cada client publica la seua identitat i
// veu la resta de jugadors connectats. La neteja és automàtica en desconnectar.
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

export interface OnlinePlayer {
  deviceId: string;
  name: string;
  /** Codi de la taula on està assegut, si n'hi ha. */
  roomCode: string | null;
}

interface PresenceState {
  deviceId: string;
  name: string;
  roomCode: string | null;
  joinedAt: number;
}

const CHANNEL_NAME = "lobby:presence";

export function useLobbyPresence({
  deviceId,
  name,
  roomCode = null,
  enabled = true,
}: {
  deviceId: string;
  name: string;
  roomCode?: string | null;
  enabled?: boolean;
}): OnlinePlayer[] {
  const [players, setPlayers] = useState<OnlinePlayer[]>([]);

  useEffect(() => {
    if (!enabled || !deviceId || !name) {
      setPlayers([]);
      return;
    }
    let cancelled = false;
    let channel: ReturnType<typeof supabase.channel> | null = null;
    let attempts = 0;
    let reconnectTimer: number | null = null;

    const teardown = () => {
      if (channel) {
        try { supabase.removeChannel(channel); } catch { /* ignore */ }
        channel = null;
      }
    };

    const scheduleReconnect = (delayOverride?: number) => {
      if (cancelled) return;
      if (reconnectTimer !== null) window.clearTimeout(reconnectTimer);
      const delay = delayOverride ?? (() => {
        // Exponential backoff with jitter, capped at 15s.
        const exp = Math.min(15_000, 500 * 2 ** Math.min(attempts, 6));
        return Math.floor(Math.random() * exp);
      })();
      attempts++;
      reconnectTimer = window.setTimeout(() => {
        if (cancelled) return;
        teardown();
        connect();
      }, delay) as unknown as number;
    };

    const connect = () => {
      if (cancelled) return;
      const ch = supabase.channel(CHANNEL_NAME, {
        config: { presence: { key: deviceId } },
      });
      channel = ch;

      const syncPlayers = () => {
        const state = ch.presenceState<PresenceState>();
        const seen = new Map<string, OnlinePlayer>();
        for (const [key, metas] of Object.entries(state)) {
          const meta = metas[0];
          if (!meta || !meta.name) continue;
          seen.set(key, {
            deviceId: meta.deviceId ?? key,
            name: meta.name,
            roomCode: meta.roomCode ?? null,
          });
        }
        setPlayers(Array.from(seen.values()).sort((a, b) => a.name.localeCompare(b.name)));
      };

      ch.on("presence", { event: "sync" }, syncPlayers)
        .on("presence", { event: "join" }, syncPlayers)
        .on("presence", { event: "leave" }, syncPlayers)
        .subscribe(async (status) => {
          if (cancelled) return;
          if (status === "SUBSCRIBED") {
            attempts = 0;
            try {
              await ch.track({
                deviceId,
                name,
                roomCode,
                joinedAt: Date.now(),
              } satisfies PresenceState);
            } catch {
              scheduleReconnect();
            }
          } else if (status === "CLOSED" || status === "CHANNEL_ERROR" || status === "TIMED_OUT") {
            scheduleReconnect();
          }
        });
    };

    connect();

    const onWake = () => {
      if (cancelled) return;
      teardown();
      attempts = 0;
      if (reconnectTimer !== null) { window.clearTimeout(reconnectTimer); reconnectTimer = null; }
      connect();
    };
    const onOnline = () => onWake();
    const onVisible = () => {
      if (typeof document !== "undefined" && document.visibilityState === "visible") onWake();
    };
    if (typeof window !== "undefined") {
      window.addEventListener("online", onOnline);
      document.addEventListener("visibilitychange", onVisible);
    }

    return () => {
      cancelled = true;
      if (reconnectTimer !== null) window.clearTimeout(reconnectTimer);
      teardown();
      if (typeof window !== "undefined") {
        window.removeEventListener("online", onOnline);
        document.removeEventListener("visibilitychange", onVisible);
      }
    };
  }, [deviceId, name, roomCode, enabled]);

  return players;
}