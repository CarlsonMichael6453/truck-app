import * as THREE from "three"
import type { Material, Mesh, Object3D } from "three"
import { barMat, caliperMat, chromeMat, glassMat, interiorMat, lampMat, plasticMat, rotorMat, rubberMat, tailMat } from "./materials"

const plateMat = plasticMat

export function assignRoleMaterials(root: Object3D, paint: Material, options?: { rim?: Material }) {
  let hasLod = false
  root.traverse((obj) => {
    if ((obj as Mesh).isMesh && obj.name.toLowerCase().includes("lod")) hasLod = true
  })
  root.traverse((obj) => {
    const mesh = obj as Mesh
    if (!mesh.isMesh) return
    const name = `${mesh.name} ${materialLabel(mesh)}`.toLowerCase()
    const lod = name.includes("lod")
    mesh.userData.lod = lod ? 1 : 0
    mesh.userData.hideWhenFar = !lod && hasLod
    mesh.visible = !lod
    mesh.castShadow = !name.includes("glass")
    mesh.receiveShadow = !name.includes("glass")
    if (name.includes("glass")) mesh.renderOrder = 4
    const chosen = choose(name, paint, options?.rim)
    const normal = sourceNormal(mesh)
    const next = normal && name.includes("rubber") ? withNormal(chosen, normal) : chosen
    if (Array.isArray(mesh.material)) mesh.material = mesh.material.map(() => next)
    else mesh.material = next
  })
}

function sourceNormal(mesh: Mesh): THREE.Texture | null {
  const slots = Array.isArray(mesh.material) ? mesh.material : [mesh.material]
  for (const slot of slots) {
    const map = (slot as THREE.MeshStandardMaterial).normalMap
    if (map) return map
  }
  return null
}

function withNormal(base: Material, map: THREE.Texture): Material {
  const next = (base as THREE.MeshStandardMaterial).clone()
  if ("normalMap" in next) {
    next.normalMap = map
    next.normalScale = new THREE.Vector2(0.85, 0.85)
  }
  return next
}

function materialLabel(mesh: Mesh): string {
  const material = mesh.material
  if (Array.isArray(material)) return material.map((item) => item.name).join(" ")
  return material?.name ?? ""
}

function choose(name: string, paint: Material, rim?: Material): Material {
  if (name.includes("glass")) return glassMat
  if (name.includes("caliper")) return caliperMat
  if (name.includes("rotor")) return rotorMat
  if (name.includes("interior")) return interiorMat
  if (name.includes("chrome")) return rim ?? chromeMat
  if (name.includes("rubber")) return rubberMat
  if (name.includes("tail")) return tailMat
  if (name.includes("light")) return name.includes("bar") ? barMat : lampMat
  if (name.includes("plate")) return plateMat
  if (name.includes("plastic")) return plasticMat
  if (name.includes("paint") || name.includes("body") || name.includes("trim")) return paint
  return rim ?? plasticMat
}
