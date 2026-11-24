import type { Lane, Track, TrackEntity } from "./types"

function build(
  prefix: string,
  rows: Array<[TrackEntity["kind"], Lane, number] | ["coins", Lane, number, number, number]>,
): TrackEntity[] {
  const list: TrackEntity[] = []
  let n = 0
  const add = (kind: TrackEntity["kind"], lane: Lane, z: number) => {
    n += 1
    list.push({ id: `${prefix}-${kind}-${n}`, kind, lane, z })
  }
  for (const row of rows) {
    if (row[0] === "coins") {
      const [, lane, start, count, gap] = row
      for (let i = 0; i < count; i += 1) add("coin", lane, start + i * gap)
    } else {
      add(row[0], row[1], row[2])
    }
  }
  return list
}

export const TRACKS: Track[] = [
  {
    id: "switchback",
    name: "Switchback",
    blurb: "A dry riverbed with one safe lane at a time.",
    length: 1120,
    speed: 30,
    unlockFinishes: 0,
    entities: build("sw", [
      ["coins", 1, 70, 4, 18],
      ["coins", 0, 150, 2, 18],
      ["rock", 1, 200],
      ["coins", 2, 240, 3, 18],
      ["rock", 0, 310],
      ["coins", 2, 350, 2, 18],
      ["barrier", 2, 410],
      ["coins", 1, 450, 2, 18],
      ["mud", 1, 510],
      ["coins", 0, 490, 3, 18],
      ["rock", 0, 580],
      ["coins", 2, 620, 3, 18],
      ["boost", 2, 680],
      ["coins", 0, 730, 3, 18],
      ["barrier", 1, 800],
      ["coins", 1, 840, 3, 18],
      ["rock", 2, 910],
      ["coins", 0, 950, 3, 18],
      ["barrier", 0, 1020],
      ["coins", 2, 1048, 3, 16],
    ]),
  },
  {
    id: "gulch",
    name: "Gulch",
    blurb: "Two lanes close at once. The open one is the whole plan.",
    length: 1080,
    speed: 32,
    unlockFinishes: 1,
    entities: build("gu", [
      ["coins", 1, 60, 4, 16],
      ["coins", 2, 150, 2, 16],
      ["rock", 0, 190],
      ["barrier", 1, 190],
      ["coins", 0, 230, 2, 16],
      ["rock", 1, 270],
      ["rock", 2, 270],
      ["coins", 1, 310, 2, 16],
      ["barrier", 0, 350],
      ["barrier", 2, 350],
      ["coins", 2, 390, 2, 16],
      ["rock", 0, 430],
      ["rock", 1, 430],
      ["boost", 2, 470],
      ["coins", 0, 500, 2, 16],
      ["barrier", 1, 540],
      ["barrier", 2, 540],
      ["coins", 1, 580, 2, 16],
      ["rock", 0, 620],
      ["rock", 2, 620],
      ["coins", 0, 660, 2, 16],
      ["barrier", 1, 700],
      ["rock", 2, 700],
      ["coins", 2, 740, 2, 16],
      ["rock", 0, 780],
      ["barrier", 1, 780],
      ["boost", 2, 820],
      ["coins", 1, 850, 2, 16],
      ["rock", 0, 890],
      ["rock", 2, 890],
      ["coins", 0, 930, 3, 16],
      ["barrier", 1, 990],
      ["barrier", 2, 990],
    ]),
  },
]

export function trackById(id: string): Track | undefined {
  return TRACKS.find((track) => track.id === id)
}
