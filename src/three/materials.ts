import { useEffect, useMemo } from "react"
import * as THREE from "three"
import { FINISHES, finishById } from "../content/catalog"
import { shadeHex } from "../lib/color"

export const chromeMat = new THREE.MeshPhysicalMaterial({
  color: "#d5dde6",
  metalness: 1,
  roughness: 0.12,
  clearcoat: 0.45,
  clearcoatRoughness: 0.08,
  envMapIntensity: 1.55,
})

export const rubberMat = new THREE.MeshStandardMaterial({
  color: "#16171a",
  roughness: 0.94,
  metalness: 0.04,
})

export const lugMat = new THREE.MeshStandardMaterial({
  color: "#2a2c30",
  roughness: 0.86,
  metalness: 0.08,
})

export const plasticMat = new THREE.MeshStandardMaterial({
  color: "#23262c",
  roughness: 0.72,
  metalness: 0.18,
})

export const linerMat = new THREE.MeshStandardMaterial({
  color: "#2c3036",
  roughness: 0.96,
  metalness: 0.02,
})

export const tubeMat = new THREE.MeshStandardMaterial({
  color: "#1a1c20",
  roughness: 0.42,
  metalness: 0.82,
})

export const glassMat = new THREE.MeshPhysicalMaterial({
  color: "#8eacbf",
  metalness: 0,
  roughness: 0.03,
  transparent: true,
  opacity: 0.14,
  clearcoat: 1,
  clearcoatRoughness: 0.02,
  envMapIntensity: 2.4,
  depthWrite: false,
  side: THREE.DoubleSide,
  polygonOffset: true,
  polygonOffsetFactor: -1,
  polygonOffsetUnits: -1,
})

export const interiorMat = new THREE.MeshStandardMaterial({
  color: "#1a120e",
  roughness: 0.78,
  metalness: 0.04,
})

export const rotorMat = new THREE.MeshStandardMaterial({
  color: "#8d9298",
  roughness: 0.42,
  metalness: 0.85,
})

export const caliperMat = new THREE.MeshStandardMaterial({
  color: "#7a2420",
  roughness: 0.48,
  metalness: 0.25,
})

export const lampMat = new THREE.MeshStandardMaterial({
  color: "#fff8ee",
  emissive: "#ffe6bf",
  emissiveIntensity: 1.7,
  roughness: 0.28,
})

export const tailMat = new THREE.MeshStandardMaterial({
  color: "#ff4a4a",
  emissive: "#ff2424",
  emissiveIntensity: 1.35,
  roughness: 0.36,
})

export const amberMat = new THREE.MeshStandardMaterial({
  color: "#ffbf70",
  emissive: "#ff9a3c",
  emissiveIntensity: 1.8,
  roughness: 0.32,
})

export const barMat = new THREE.MeshStandardMaterial({
  color: "#f5f7ff",
  emissive: "#e7eeff",
  emissiveIntensity: 2.1,
  roughness: 0.22,
})

export const circuitMat = new THREE.MeshStandardMaterial({
  color: "#123832",
  emissive: "#39f0d0",
  emissiveIntensity: 1.6,
  roughness: 0.38,
  metalness: 0.25,
})

export function usePaintMaterial(color: string, finishId: string) {
  const finish = finishById(finishId) ?? FINISHES[0]
  const material = useMemo(() => {
    return new THREE.MeshPhysicalMaterial({
      color,
      metalness: finish?.metalness ?? 0.1,
      roughness: finish?.roughness ?? 0.2,
      clearcoat: finish?.clearcoat ?? 1,
      clearcoatRoughness: finish?.clearcoatRoughness ?? 0.08,
      iridescence: finish?.iridescence ?? 0,
      iridescenceIOR: 1.4,
      iridescenceThicknessMinimum: 140,
      iridescenceThicknessMaximum: 520,
      envMapIntensity: 1.25,
    })
  }, [color, finish])
  useEffect(() => () => material.dispose(), [material])
  return material
}

export function useTrimMaterial(color: string) {
  const material = useMemo(
    () =>
      new THREE.MeshPhysicalMaterial({
        color: shadeHex(color, -48),
        metalness: 0.28,
        roughness: 0.52,
        clearcoat: 0.25,
        clearcoatRoughness: 0.35,
        envMapIntensity: 1,
      }),
    [color],
  )
  useEffect(() => () => material.dispose(), [material])
  return material
}

export function useRimMaterial(color: string, metalness: number, roughness: number) {
  const material = useMemo(
    () =>
      new THREE.MeshPhysicalMaterial({
        color,
        metalness,
        roughness,
        clearcoat: metalness > 0.8 ? 0.4 : 0.1,
        clearcoatRoughness: 0.12,
        envMapIntensity: 1.3,
      }),
    [color, metalness, roughness],
  )
  useEffect(() => () => material.dispose(), [material])
  return material
}
