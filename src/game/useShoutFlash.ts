/**
 * Hook compartit que deriva el "flash" transitori d'un cant a partir del
 * `match.round.log`. Detecta quan apareix un nou esdeveniment `shout` i el
 * mostra durant ~1.6s. S'utilitza tant en la partida offline (`useTrucMatch`)
 * com en la partida online (`OnlinePartida`) perquè l'animació sigui idèntica.
 *
 * Per a respostes a un cant ("vull" / "no-vull"), permet apilar fins a un
 * flash per jugador alhora — així si els dos membres d'un equip diuen
 * "no vull" es veuen els dos carteles simultàniament al centre, cadascun
 * amb la cua del bocadillo apuntant al seu autor.
 */
import { useEffect, useRef, useState } from "react";
import { VISUAL_EVENT_GAP_MS } from "./chatTimings";
import { speakShout } from "@/lib/speech";
import { computeShoutDisplay } from "./shoutDisplay";
import type { MatchState, PlayerId, ShoutKind } from "./types";

export interface ShoutFlash {
  player: PlayerId;
  what: ShoutKind;
  labelOverride?: string;
}

const QUESTION_SHOUTS: ReadonlySet<ShoutKind> = new Set([
  "envit", "renvit", "falta-envit",
  "truc", "retruc", "quatre", "joc-fora",
]);

const RESPONSE_SHOUTS: ReadonlySet<ShoutKind> = new Set([
  "vull", "no-vull",
]);

/** Cants que es locuten en veu alta exactament quan apareix el cartell central. */
const SPOKEN_SHOUTS: ReadonlySet<ShoutKind> = new Set([
  "truc", "retruc", "quatre", "joc-fora",
  "envit", "renvit", "falta-envit",
  "vull", "no-vull",
]);

const SHOUT_FLASH_HIDE_MS = 1600;
/**
 * Quan una resposta ("vull" / "no-vull") apareix mentre una altra encara
 * està visible, la segona s'ha d'amagar abans que aparega la nova. Aquest
 * delay (lleugerament > SHOUT_FLASH_HIDE_MS) garanteix que mai es mostren
 * dos carteles centrals alhora — així es queden sempre centrats.
 */
const RESPONSE_TO_RESPONSE_MIN_GAP_MS = SHOUT_FLASH_HIDE_MS + 200;

/**
 * Hook que retorna la llista de flashes actius. Per a preguntes (envit,
 * truc, etc.) sempre hi haurà com a molt un flash visible alhora — el cant
 * més recent substitueix l'anterior. Per a respostes ("vull" / "no-vull")
 * els flashes s'acumulen, un per jugador, perquè es vegin els dos membres
 * de l'equip dient "no vull" alhora.
 */
export function useShoutFlashes(match: MatchState | null): ShoutFlash[] {
  const [flashes, setFlashes] = useState<ShoutFlash[]>([]);
  const lastSeenIdxRef = useRef<number>(-1);
  const timersRef = useRef<number[]>([]);
  const nextVisibleAtRef = useRef(0);
  const roundKeyRef = useRef<string | null>(null);
  const lastWasResponseRef = useRef(false);
  const lastResponseShownAtRef = useRef(0);

  useEffect(() => {
    if (!match) return;
    // La `roundKey` ha d'identificar UNÍVOCAMENT la ronda en curs (la que
    // viu actualment a `match.round.log`), no la "posició dins la partida".
    // Quan una mà acaba, el motor fa `m.history.push(summary)` i marca la
    // fase com `round-end` ABANS que arribe el següent `startNextRound`.
    // En el mode online aquest estat intermedi es publica al servidor amb
    // un delay (LOW_LATENCY_ROUND_END_MS), per la qual cosa el client veu
    // un render amb `history.length` ja incrementat però el `round.log`
    // encara contenint TOTS els shouts d'aquesta mà. Si la `roundKey`
    // depenguera de `history.length`, canviaria en aquest precís moment i
    // el hook reprocesaria tot el log com si fos una ronda nova,
    // re-mostrant tots els carteles centrats que ja s'havien vist.
    // Solució: durant `round-end`/`game-end` la mà visible segueix sent la
    // mateixa que abans de l'`history.push`, així que normalitzem la key
    // restant 1. En la pròxima ronda, `startNextRound` reinicia `round`
    // amb un `mano`/`dealer` nou i el log buit (només el `deal` event),
    // canviant la key i resetejant els flashes correctament.
    const isRoundEnd =
      match.round.phase === "round-end" || match.round.phase === "game-end";
    const historyLenForKey = isRoundEnd
      ? Math.max(0, match.history.length - 1)
      : match.history.length;
    const roundKey = `${historyLenForKey}-${match.cames}-${match.round.mano}`;
    if (roundKeyRef.current !== roundKey) {
      roundKeyRef.current = roundKey;
      timersRef.current.forEach((timer) => window.clearTimeout(timer));
      timersRef.current = [];
      nextVisibleAtRef.current = 0;
      lastSeenIdxRef.current = -1;
      lastWasResponseRef.current = false;
      lastResponseShownAtRef.current = 0;
      setFlashes([]);
    }
    const log = match.round.log;
    // Process all new `shout` events since the last one we saw. When the
    // online server applies several bot actions in a single tick, multiple
    // shouts (or "vull" / "no-vull" responses) arrive in the same React
    // render. To match the offline behaviour — where each bot acts one at
    // a time with `BOT_DELAY_MS` between actions — we STAGGER successive
    // flashes by `VISUAL_EVENT_GAP_MS`. The first new flash always shows
    // immediately; later flashes from the same batch are scheduled into
    // the future so they pop one after another, with the same cadence the
    // offline match produces naturally.
    const start = lastSeenIdxRef.current + 1;
    const now = Date.now();
    if (nextVisibleAtRef.current < now) nextVisibleAtRef.current = now;
    for (let i = start; i < log.length; i++) {
      const ev = log[i];
      lastSeenIdxRef.current = i;
      if (ev.type === "trick-end") {
        const showAt = nextVisibleAtRef.current;
        const delay = Math.max(0, showAt - now);
        const clearTimer = window.setTimeout(() => {
          timersRef.current.forEach((t) => window.clearTimeout(t));
          timersRef.current = [];
          setFlashes([]);
        }, delay) as unknown as number;
        timersRef.current.push(clearTimer);
        // Trick-end does not consume a new visual gap by itself.
        continue;
      }
      if (ev.type !== "shout") continue;
      const display = computeShoutDisplay(match);
      const labelOverride = display.shoutLabelByPlayer[ev.player] ?? undefined;
      const isResponse = RESPONSE_SHOUTS.has(ev.what);
      const hidesAutomatically = !QUESTION_SHOUTS.has(ev.what);
      const player = ev.player;
      const what = ev.what;

      // Si l'esdeveniment anterior d'aquesta tanda també era una resposta,
      // força un gap mínim equivalent al temps que el primer cartell està
      // visible. Així mai s'apilen dos carteles centrals alhora i cadascun
      // queda perfectament centrat.
      if (isResponse && lastWasResponseRef.current) {
        const minNext = lastResponseShownAtRef.current + RESPONSE_TO_RESPONSE_MIN_GAP_MS;
        if (nextVisibleAtRef.current < minNext) nextVisibleAtRef.current = minNext;
      }

      const showAt = nextVisibleAtRef.current;
      const delay = Math.max(0, showAt - now);
      // Reserve the slot so the NEXT flash is staggered after this one.
      nextVisibleAtRef.current = showAt + VISUAL_EVENT_GAP_MS;
      lastWasResponseRef.current = isResponse;
      if (isResponse) lastResponseShownAtRef.current = showAt;

      const showTimer = window.setTimeout(() => {
        setFlashes(() => {
          // Sempre un únic cartell central visible alhora — tant per
          // preguntes com per respostes.
          return [{ player, what, labelOverride }];
        });
        // Locuta el cant EXACTAMENT quan apareix el cartell central,
        // perquè la veu i el text estiguen perfectament sincronitzats
        // (sense el desfase del staggering visual).
        if (SPOKEN_SHOUTS.has(what)) {
          speakShout(what, labelOverride);
        }
        if (hidesAutomatically) {
          const hideTimer = window.setTimeout(() => {
            setFlashes((curr) => curr.filter((f) => !(f.player === player && f.what === what)));
          }, SHOUT_FLASH_HIDE_MS) as unknown as number;
          timersRef.current.push(hideTimer);
        }
      }, delay) as unknown as number;
      timersRef.current.push(showTimer);
    }
  }, [match]);

  // Neteja en desmuntar.
  useEffect(() => {
    return () => {
      timersRef.current.forEach((timer) => window.clearTimeout(timer));
      timersRef.current = [];
    };
  }, []);

  return flashes;
}

/**
 * Compatibilitat enrere: retorna només el flash més recent (l'últim de la
 * llista) per a llocs que encara consumeixen un únic flash.
 */
export function useShoutFlash(match: MatchState | null): ShoutFlash | null {
  const list = useShoutFlashes(match);
  return list.length === 0 ? null : list[list.length - 1];
}