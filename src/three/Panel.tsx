import { RoundedBox } from "@react-three/drei"
import type { Material } from "three"

type PanelProps = {
  size: [number, number, number]
  position: [number, number, number]
  rotation?: [number, number, number]
  material: Material
  radius?: number
}

export function Panel({ size, position, rotation, material, radius = 0.045 }: PanelProps) {
  const [width, height, depth] = size
  const safe = Math.min(radius, width * 0.18, height * 0.18, depth * 0.18)
  if (safe < 0.012) {
    return (
      <mesh position={position} rotation={rotation} material={material}>
        <boxGeometry args={size} />
      </mesh>
    )
  }
  return (
    <RoundedBox
      args={size}
      radius={safe}
      smoothness={2}
      bevelSegments={1}
      position={position}
      rotation={rotation}
      material={material}
    />
  )
}
