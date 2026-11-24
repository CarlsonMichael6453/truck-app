import { ContactShadows, Environment, Lightformer, OrbitControls } from "@react-three/drei"
import { Canvas } from "@react-three/fiber"
import { Bloom, EffectComposer, Vignette } from "@react-three/postprocessing"
import { Suspense, useEffect, useMemo, useState } from "react"
import * as THREE from "three"
import { TRUCKS } from "../content/catalog"
import type { Loadout, TruckSpec } from "../content/types"
import { preloadTrucks, TruckModel } from "./TruckModel"
import { makeBlobTexture, makeConcreteTexture, makePosterTexture, makeWallTexture } from "./textures"

const TARGET: [number, number, number] = [0, 0.9, 0.1]

function shotView(): { pos: [number, number, number]; target: [number, number, number] } | null {
  if (typeof window === "undefined") return null
  const view = new URLSearchParams(window.location.search).get("view")
  if (view === "wheel") return { pos: [1.7, 0.55, 2.45], target: [0.78, 0.4, 1.7] }
  if (view === "bumper") return { pos: [1.15, 0.5, 3.25], target: [0, 0.42, 2.4] }
  if (view === "glass") return { pos: [1.9, 1.28, 1.05], target: [0.45, 1.25, 0.4] }
  return null
}

function SetDressing() {
  const concrete = useMemo(() => makeConcreteTexture(), [])
  const wall = useMemo(() => makeWallTexture(), [])
  const blob = useMemo(() => makeBlobTexture(), [])
  const poster = useMemo(() => makePosterTexture(), [])
  useEffect(
    () => () => {
      concrete.dispose()
      wall.dispose()
      blob.dispose()
      poster.dispose()
    },
    [concrete, wall, blob, poster],
  )
  return (
    <group>
      <mesh rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <circleGeometry args={[14, 72]} />
        <meshStandardMaterial map={concrete} roughness={0.62} metalness={0.22} color="#c5c8d0" envMapIntensity={0.7} />
      </mesh>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.008, 0.15]}>
        <circleGeometry args={[2.4, 40]} />
        <meshBasicMaterial map={blob} transparent depthWrite={false} />
      </mesh>
      <mesh position={[0, 2.1, 0]}>
        <cylinderGeometry args={[11, 13, 5.2, 48, 1, true]} />
        <meshBasicMaterial map={wall} side={THREE.BackSide} />
      </mesh>
      <mesh position={[0, 4.4, 0]} rotation={[Math.PI / 2, 0, 0]}>
        <circleGeometry args={[11, 32]} />
        <meshBasicMaterial color="#12141a" side={THREE.BackSide} />
      </mesh>
      <mesh position={[-1.1, 3.55, 0.2]} rotation={[Math.PI / 2, 0, 0]}>
        <planeGeometry args={[3.2, 0.45]} />
        <meshBasicMaterial color="#fff1df" />
      </mesh>
      <mesh position={[2.4, 3.2, -1.4]} rotation={[0.4, -0.5, 0]}>
        <planeGeometry args={[1.6, 0.7]} />
        <meshBasicMaterial color="#d5e2ff" />
      </mesh>
      <mesh position={[-4.2, 1.7, -2.2]} rotation={[0, 0.5, 0]}>
        <planeGeometry args={[1.1, 1.7]} />
        <meshStandardMaterial map={poster} roughness={0.8} />
      </mesh>
      <mesh position={[-3.3, 0.55, -0.6]}>
        <boxGeometry args={[0.7, 1.1, 0.42]} />
        <meshStandardMaterial color="#2a241e" roughness={0.55} metalness={0.35} />
      </mesh>
    </group>
  )
}

function Lights() {
  return (
    <>
      <ambientLight intensity={0.18} />
      <directionalLight
        position={[5.2, 7.2, 4.2]}
        intensity={2.6}
        color="#fff3e6"
        castShadow
        shadow-mapSize-width={1024}
        shadow-mapSize-height={1024}
        shadow-camera-near={1}
        shadow-camera-far={18}
        shadow-camera-left={-6}
        shadow-camera-right={6}
        shadow-camera-top={6}
        shadow-camera-bottom={-6}
        shadow-bias={-0.00035}
      />
      <directionalLight position={[-5.5, 3.4, -3.2]} intensity={1.35} color="#9eb4ff" />
      <spotLight position={[0.4, 4.6, 1.2]} angle={0.55} penumbra={0.85} intensity={12} color="#fffaf4" distance={12} />
    </>
  )
}

function LookControls({ active }: { active: boolean }) {
  const shot = useMemo(() => shotView(), [])
  const reduced = useMemo(
    () => typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches,
    [],
  )
  const [moved, setMoved] = useState(false)
  return (
    <OrbitControls
      enablePan={false}
      enableDamping
      dampingFactor={0.08}
      autoRotate={active && !reduced && !moved && !shot}
      autoRotateSpeed={0.55}
      minPolarAngle={shot ? 0.4 : 0.95}
      maxPolarAngle={shot ? 1.7 : 1.4}
      minDistance={shot ? 0.35 : 3.6}
      maxDistance={8.4}
      target={shot?.target ?? TARGET}
      onStart={() => setMoved(true)}
    />
  )
}

export function GarageScene({ spec, loadout, active }: { spec: TruckSpec; loadout: Loadout; active: boolean }) {
  const shot = useMemo(() => shotView(), [])
  const fancy = useMemo(() => {
    if (typeof window === "undefined") return true
    return !window.matchMedia("(pointer: coarse)").matches
  }, [])
  useEffect(() => {
    preloadTrucks(TRUCKS.map((truck) => truck.id))
  }, [])
  return (
    <Canvas
      className="h-full w-full touch-none"
      dpr={[1, 1.6]}
      shadows
      frameloop={active ? "always" : "never"}
      camera={{ position: shot?.pos ?? [4.6, 1.7, 5.5], fov: shot ? 28 : 32, near: 0.05, far: 40 }}
      gl={{ antialias: true, alpha: false, powerPreference: "high-performance" }}
      onCreated={({ gl, camera }) => {
        gl.toneMapping = THREE.ACESFilmicToneMapping
        gl.toneMappingExposure = 1.02
        gl.shadowMap.type = THREE.PCFShadowMap
        gl.outputColorSpace = THREE.SRGBColorSpace
        camera.lookAt(...(shot?.target ?? TARGET))
      }}
    >
      <color attach="background" args={["#12141a"]} />
      <Suspense fallback={null}>
        <Environment frames={1} resolution={fancy ? 512 : 256} environmentIntensity={1.2}>
          <Lightformer form="rect" intensity={4} color="#fff4e8" position={[0, 4.2, -1]} scale={[9, 2.2, 1]} />
          <Lightformer form="rect" intensity={2.2} color="#ffc49a" position={[4.2, 2.2, 2]} scale={[3.2, 2.4, 1]} />
          <Lightformer form="rect" intensity={2.4} color="#a9c0ff" position={[-4.4, 2.4, -2]} scale={[3.4, 1.8, 1]} />
          <Lightformer form="rect" intensity={0.7} color="#6d5b4c" position={[0, -1.2, 0]} rotation={[-Math.PI / 2, 0, 0]} scale={[12, 12, 1]} />
        </Environment>
        <TruckModel spec={spec} loadout={loadout} />
      </Suspense>
      <Lights />
      <SetDressing />
      <ContactShadows position={[0, 0.01, 0.1]} opacity={0.48} scale={14} blur={2.4} far={4.2} resolution={512} />
      <LookControls active={active} />
      {fancy ? (
        <EffectComposer enableNormalPass={false} multisampling={0}>
          <Bloom intensity={0.16} luminanceThreshold={0.86} mipmapBlur radius={0.35} />
          <Vignette eskil={false} offset={0.18} darkness={0.55} />
        </EffectComposer>
      ) : null}
    </Canvas>
  )
}
