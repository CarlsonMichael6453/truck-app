import { findModelUrl } from "./models"

export const modelFiles = import.meta.glob("../assets/models/**/*.glb", {
  eager: true,
  query: "?url",
  import: "default",
}) as Record<string, string>

export function truckModelUrl(id: string): string | undefined {
  return findModelUrl(modelFiles, "trucks", id)
}

export function partModelUrl(id: string): string | undefined {
  return findModelUrl(modelFiles, "parts", id)
}
