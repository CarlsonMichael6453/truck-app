import { useGLTF } from "@react-three/drei"
import { useFrame } from "@react-three/fiber"
import { useEffect, useLayoutEffect, useMemo, useRef } from "react"
import type { Group, Material } from "three"
import { paintById, partById } from "../content/catalog"
import type { TruckAnchors } from "../content/fit"
import type { Loadout, Part } from "../content/types"
import { partModelUrl } from "../game/modelFiles"
import { assignRoleMaterials } from "./assignMaterials"
import { circuitMat, plasticMat, rubberMat, usePaintMaterial, useRimMaterial } from "./materials"
import { makeSunsetTexture } from "./textures"

function useSpin() {
  const ref = useRef<Group>(null)
  const reduced = useRef(false)
  useEffect(() => {
    reduced.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }, [])
  useFrame((_, delta) => {
    if (!ref.current || reduced.current) return
    ref.current.rotation.x -= delta * 0.7
  })
  return ref
}

function Glb({ url, paint, rim }: { url: string; paint?: Material; rim?: Material }) {
  const { scene } = useGLTF(url)
  const cloned = useMemo(() => scene.clone(true), [scene])
  useLayoutEffect(() => {
    if (paint) assignRoleMaterials(cloned, paint, { rim })
  }, [cloned, paint, rim])
  return <primitive object={cloned} />
}

function slotPart<S extends Part["slot"]>(id: string, slot: S): Extract<Part, { slot: S }> | undefined {
  const part = partById(id)
  if (part && part.slot === slot) return part as Extract<Part, { slot: S }>
  return undefined
}

function WrapDecals({ anchors, loadout }: { anchors: TruckAnchors; loadout: Loadout }) {
  const wrap = slotPart(loadout.wrap, "wrap")
  if (!wrap || wrap.look.kind === "clean") return null
  const accent = wrap.look.accent
  const y = anchors.lightbar[1] - 0.7
  const z = (anchors.lightbar[2] + anchors.spoiler[2]) / 2
  if (wrap.look.kind === "stripe") {
    return (
      <group>
        {[-1, 1].map((side) => (
          <mesh key={side} position={[side * 0.92, y, z]}>
            <boxGeometry args={[0.012, 0.045, 1.35]} />
            <meshStandardMaterial color={accent} roughness={0.35} metalness={0.2} />
          </mesh>
        ))}
      </group>
    )
  }
  if (wrap.look.kind === "geo") {
    return (
      <group>
        {[-1, 1].map((side) =>
          [0, 1, 2].map((index) => (
            <mesh key={`${side}-${index}`} position={[side * 0.93, y, z - 0.45 + index * 0.38]} rotation={[0, 0, side * 0.45]}>
              <boxGeometry args={[0.012, 0.16, 0.07]} />
              <meshStandardMaterial color={accent} roughness={0.4} metalness={0.25} />
            </mesh>
          )),
        )}
      </group>
    )
  }
  if (wrap.look.kind === "sunset") return <SunsetDecal y={y} z={z} accent={accent} />
  return (
    <group>
      {[-1, 1].map((side) => (
        <mesh key={side} position={[side * 0.93, y, z]} material={circuitMat}>
          <boxGeometry args={[0.01, 0.012, 1.2]} />
        </mesh>
      ))}
    </group>
  )
}

function SunsetDecal({ y, z, accent }: { y: number; z: number; accent: string }) {
  const map = useMemo(() => makeSunsetTexture(accent), [accent])
  useEffect(() => () => map.dispose(), [map])
  return (
    <group>
      {[-1, 1].map((side) => (
        <mesh key={side} position={[side * 0.94, y, z]} rotation={[0, side > 0 ? Math.PI / 2 : -Math.PI / 2, 0]}>
          <planeGeometry args={[1.3, 0.42]} />
          <meshStandardMaterial map={map} transparent roughness={0.4} polygonOffset polygonOffsetFactor={-1} polygonOffsetUnits={-1} />
        </mesh>
      ))}
    </group>
  )
}

export function TruckAccessories({
  loadout,
  anchors,
  mode,
  tireRadius = 0.38,
}: {
  loadout: Loadout
  anchors: TruckAnchors
  mode: "body" | "wheels"
  tireRadius?: number
}) {
  const paintHex = paintById(loadout.paint)?.hex ?? "#c4622d"
  const paint = usePaintMaterial(paintHex, loadout.finish)
  const wheel = slotPart(loadout.wheel, "wheel")
  const bumper = slotPart(loadout.bumper, "bumper")
  const light = slotPart(loadout.light, "light")
  const exhaust = slotPart(loadout.exhaust, "exhaust")
  const spoiler = slotPart(loadout.spoiler, "spoiler")
  const rimMat = useRimMaterial(wheel?.look.color ?? "#d5dde6", wheel?.look.metalness ?? 1, wheel?.look.roughness ?? 0.16)
  if (mode === "wheels") {
    const tireUrl = partModelUrl(loadout.tire)
    const rimUrl = wheel ? partModelUrl(wheel.id) : undefined
    return (
      <group>
        {anchors.wheels.map((wheelAnchor) => (
          <Wheel
            key={wheelAnchor.id}
            position={[wheelAnchor.position[0], tireRadius, wheelAnchor.position[2]]}
            outward={wheelAnchor.position[0] < 0}
            tireUrl={tireUrl}
            rimUrl={rimUrl}
            rimMat={rimMat}
          />
        ))}
      </group>
    )
  }
  const bumperUrl = bumper ? partModelUrl(bumper.id) : undefined
  const lightUrl = light ? partModelUrl(light.id) : undefined
  const exhaustUrl = exhaust ? partModelUrl(exhaust.id) : undefined
  const spoilerUrl = spoiler && spoiler.look.kind !== "none" ? partModelUrl(spoiler.id) : undefined
  return (
    <group>
      {bumperUrl ? (
        <>
          <group position={anchors.bumperFront}>
            <Glb url={bumperUrl} paint={paint} />
          </group>
          <group position={anchors.bumperRear} rotation={[0, Math.PI, 0]}>
            <Glb url={bumperUrl} paint={paint} />
          </group>
        </>
      ) : null}
      {lightUrl ? (
        <group position={anchors.lightbar}>
          <Glb url={lightUrl} paint={plasticMat} />
        </group>
      ) : null}
      {exhaustUrl ? (
        <group position={anchors.exhaust}>
          <Glb url={exhaustUrl} paint={paint} />
        </group>
      ) : null}
      {spoilerUrl ? (
        <group position={anchors.spoiler}>
          <Glb url={spoilerUrl} paint={paint} />
        </group>
      ) : null}
      <WrapDecals anchors={anchors} loadout={loadout} />
    </group>
  )
}

function Wheel({
  position,
  outward,
  tireUrl,
  rimUrl,
  rimMat,
}: {
  position: [number, number, number]
  outward: boolean
  tireUrl?: string
  rimUrl?: string
  rimMat: Material
}) {
  const spin = useSpin()
  return (
    <group position={position} ref={spin}>
      <group rotation={[0, outward ? Math.PI : 0, 0]}>
        {tireUrl ? <Glb url={tireUrl} paint={rubberMat} /> : null}
        {rimUrl ? <Glb url={rimUrl} paint={rimMat} rim={rimMat} /> : null}
      </group>
    </group>
  )
}
