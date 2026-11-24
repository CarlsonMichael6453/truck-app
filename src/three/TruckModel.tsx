import { useGLTF } from "@react-three/drei"
import { useLayoutEffect, useMemo } from "react"
import { paintById } from "../content/catalog"
import { anchorsFor } from "../content/fit"
import type { Loadout, TruckSpec } from "../content/types"
import { partById } from "../content/catalog"
import { truckModelUrl } from "../game/modelFiles"
import { assignRoleMaterials } from "./assignMaterials"
import { usePaintMaterial } from "./materials"
import { TruckAccessories } from "./parts"

function BodyGlb({ url, color, finish }: { url: string; color: string; finish: string }) {
  const { scene } = useGLTF(url)
  const paint = usePaintMaterial(color, finish)
  const cloned = useMemo(() => scene.clone(true), [scene])
  useLayoutEffect(() => {
    assignRoleMaterials(cloned, paint)
  }, [cloned, paint])
  return <primitive object={cloned} />
}

export function TruckModel({ spec, loadout }: { spec: TruckSpec; loadout: Loadout }) {
  const url = truckModelUrl(spec.id)
  const tire = partById(loadout.tire)
  const lift = partById(loadout.lift)
  const tireRadius = tire?.slot === "tire" ? tire.look.radius : 0.38
  const liftAmount = (lift?.slot === "lift" ? lift.look.amount : 0) + Math.max(0, tireRadius - 0.38)
  const anchors = anchorsFor(spec)
  const color = paintById(loadout.paint)?.hex ?? "#c4622d"
  return (
    <group>
      <group position={[0, liftAmount, 0]}>
        {url ? <BodyGlb url={url} color={color} finish={loadout.finish} /> : null}
        <TruckAccessories loadout={loadout} anchors={anchors} mode="body" />
      </group>
      <TruckAccessories loadout={loadout} anchors={anchors} mode="wheels" tireRadius={tireRadius} />
    </group>
  )
}

export function preloadTrucks(ids: string[]) {
  for (const id of ids) {
    const url = truckModelUrl(id)
    if (url) useGLTF.preload(url)
  }
}
