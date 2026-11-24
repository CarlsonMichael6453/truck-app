import type { Material, Mesh, Object3D } from "three"
import { barMat, chromeMat, glassMat, lampMat, plasticMat, rubberMat, tailMat } from "./materials"

const plateMat = plasticMat

export function assignRoleMaterials(root: Object3D, paint: Material, options?: { rim?: Material }) {
  root.traverse((obj) => {
    const mesh = obj as Mesh
    if (!mesh.isMesh) return
    const name = `${mesh.name} ${materialLabel(mesh)}`.toLowerCase()
    mesh.castShadow = !name.includes("glass")
    mesh.receiveShadow = !name.includes("glass")
    mesh.material = choose(name, paint, options?.rim)
  })
}

function materialLabel(mesh: Mesh): string {
  const material = mesh.material
  if (Array.isArray(material)) return material.map((item) => item.name).join(" ")
  return material?.name ?? ""
}

function choose(name: string, paint: Material, rim?: Material): Material {
  if (name.includes("glass")) return glassMat
  if (name.includes("chrome")) return rim ?? chromeMat
  if (name.includes("rubber")) return rubberMat
  if (name.includes("tail")) return tailMat
  if (name.includes("light")) return name.includes("bar") ? barMat : lampMat
  if (name.includes("plate")) return plateMat
  if (name.includes("interior") || name.includes("plastic")) return plasticMat
  if (name.includes("paint") || name.includes("body") || name.includes("trim")) return paint
  return rim ?? plasticMat
}
