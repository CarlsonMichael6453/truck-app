/**
 * GLB lookup is filename-based so a new file can be dropped in without editing
 * the loader. Catalog `fit` is only for nudging a model that doesn't sit right.
 */
export function findModelUrl(
  files: Record<string, string>,
  kind: "trucks" | "parts",
  id: string,
): string | undefined {
  const suffix = `/models/${kind}/${id}.glb`.toLowerCase()
  for (const [key, url] of Object.entries(files)) {
    const norm = key.replaceAll("\\", "/").toLowerCase()
    if (norm.endsWith(suffix) && url) return url
  }
  return undefined
}
